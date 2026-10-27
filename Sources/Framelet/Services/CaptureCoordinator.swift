import Foundation
import Observation
import AppKit
import ScreenCaptureKit
import AVFoundation
import CoreMedia
import CoreVideo
import FrameletCore

private final class CaptureSelectionObserver: NSObject, SCContentSharingPickerObserver {
    var selected: ((SCContentFilter) -> Void)?
    var cancelled: (() -> Void)?
    var failed: (() -> Void)?

    func contentSharingPicker(_ picker: SCContentSharingPicker, didUpdateWith filter: SCContentFilter, for stream: SCStream?) {
        guard stream == nil else { return }
        selected?(filter)
    }
    func contentSharingPicker(_ picker: SCContentSharingPicker, didCancelFor stream: SCStream?) {
        guard stream == nil else { return }
        cancelled?()
    }
    func contentSharingPickerStartDidFailWithError(_ error: Error) { failed?() }
}

private final class CaptureSegment {
    let id: UUID
    let screenPath: String
    let cameraPath: String?
    let screen: ScreenRecording
    let camera: CameraRecorder?
    var screenHost: Double?
    var cameraHost: Double?

    init(id: UUID, screenPath: String, cameraPath: String?, screen: ScreenRecording, camera: CameraRecorder?) {
        self.id = id; self.screenPath = screenPath; self.cameraPath = cameraPath
        self.screen = screen; self.camera = camera
    }
    var hasUnfinishedCapture: Bool { screen.hasUnfinishedCapture || camera?.hasUnfinishedCapture == true }
}

@MainActor @Observable
final class CaptureCoordinator {
    private(set) var phase: CapturePhase = .idle
    var options = CaptureOptions()
    private(set) var selectedSourceName: String?
    private(set) var projectID: UUID?
    private(set) var elapsedSeconds: Double = 0
    private(set) var countdownRemaining = 0
    private(set) var errorMessage: String?
    private(set) var cameraSession: AVCaptureSession?
    private(set) var hasUnfinishedCapture = false

    @ObservationIgnored private let library: RecordingLibrary
    @ObservationIgnored private var filter: SCContentFilter?
    @ObservationIgnored private var pickerObserver: CaptureSelectionObserver?
    @ObservationIgnored private var phaseBeforePicker: CapturePhase = .idle
    @ObservationIgnored private var project: RecordingProject?
    @ObservationIgnored private var active: CaptureSegment?
    @ObservationIgnored private var retiring: [CaptureSegment] = []
    @ObservationIgnored private var epoch = UUID()
    @ObservationIgnored private var elapsedTask: Task<Void, Never>?

    init(library: RecordingLibrary) { self.library = library }

    func chooseSource() {
        resourcesChanged()
        guard (phase == .idle || phase == .failed), !hasUnfinishedCapture else { return }
        phaseBeforePicker = phase
        phase = .choosing
        errorMessage = nil
        if pickerObserver == nil {
            let observer = CaptureSelectionObserver()
            observer.selected = { [weak self] filter in
                Task { @MainActor [weak self] in self?.acceptSelection(filter) }
            }
            observer.cancelled = { [weak self] in
                Task { @MainActor [weak self] in
                    guard let self, self.phase == .choosing else { return }
                    self.phase = self.phaseBeforePicker
                }
            }
            observer.failed = { [weak self] in
                Task { @MainActor [weak self] in
                    guard let self, self.phase == .choosing else { return }
                    self.errorMessage = "The source picker could not open. Try choosing a display or window again."
                    self.phase = self.phaseBeforePicker
                }
            }
            pickerObserver = observer
            SCContentSharingPicker.shared.add(observer)
        }
        var configuration = SCContentSharingPickerConfiguration()
        configuration.allowedPickerModes = [.singleDisplay, .singleWindow]
        configuration.allowsChangingSelectedContent = false
        if let bundleID = Bundle.main.bundleIdentifier { configuration.excludedBundleIDs = [bundleID] }
        let picker = SCContentSharingPicker.shared
        picker.defaultConfiguration = configuration
        picker.maximumStreamCount = 1
        picker.isActive = true
        picker.present()
    }

    private func acceptSelection(_ filter: SCContentFilter) {
        guard phase == .choosing else { return }
        self.filter = filter
        selectedSourceName = filter.style == .display ? "Selected display" : "Selected window"
        phase = .idle
    }

    func start() async {
        resourcesChanged()
        guard phase == .idle || phase == .failed else { return }
        guard !hasUnfinishedCapture else {
            errorMessage = "The previous capture is still finishing. Use Stop again before starting another recording."
            return
        }
        guard let filter else { errorMessage = "Choose a display or window before recording."; return }
        let chosenOptions = options
        guard (0...10).contains(chosenOptions.countdownSeconds) else {
            errorMessage = "Choose a countdown between zero and ten seconds."; return
        }
        let operation = UUID()
        epoch = operation
        project = nil
        projectID = nil
        elapsedSeconds = 0
        errorMessage = nil
        phase = .starting
        do {
            try await authorizeDevices(chosenOptions, operation: operation)
            guard epoch == operation else { return }
            if chosenOptions.countdownSeconds > 0 {
                phase = .countdown
                for remaining in stride(from: chosenOptions.countdownSeconds, through: 1, by: -1) {
                    guard epoch == operation else { return }
                    countdownRemaining = remaining
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                }
            }
            guard epoch == operation else { return }
            countdownRemaining = 0
            phase = .starting
            let created = try library.create(options: chosenOptions)
            project = created
            projectID = created.id
            try await beginSegment(filter: filter, operation: operation)
            guard epoch == operation else { return }
            phase = .recording
            startElapsedUpdates()
        } catch {
            guard epoch == operation else { return }
            await failCapture(error)
        }
    }

    func pause() async {
        guard phase == .recording else { return }
        phase = .pausing
        elapsedTask?.cancel()
        do {
            try await finishActiveSegment()
            try saveStatus(.paused)
            phase = .paused
        } catch { await failCapture(error) }
    }

    func resume() async {
        resourcesChanged()
        guard phase == .paused, !hasUnfinishedCapture, let filter, project != nil else { return }
        let operation = UUID()
        epoch = operation
        phase = .starting
        errorMessage = nil
        do {
            try saveStatus(.recording)
            try await beginSegment(filter: filter, operation: operation)
            guard epoch == operation else { return }
            phase = .recording
            startElapsedUpdates()
        } catch {
            guard epoch == operation else { return }
            await failCapture(error)
        }
    }

    func stop() async {
        guard phase != .pausing && phase != .stopping else { return }
        guard phase != .idle && phase != .choosing || hasUnfinishedCapture else { return }
        let wasFailed = phase == .failed
        epoch = UUID()
        countdownRemaining = 0
        elapsedTask?.cancel()
        phase = .stopping
        do {
            if let active {
                if wasFailed {
                    try await stopResources(active)
                    retiring.append(active)
                    self.active = nil
                } else { try await finishActiveSegment() }
            }
            for segment in retiring { try await stopResources(segment) }
            resourcesChanged()
            guard !hasUnfinishedCapture else {
                throw CaptureError.message("The recording has not finished shutting down. Try Stop again; keep the app open.")
            }
            cameraSession = nil
            if let project {
                try saveStatus(wasFailed || project.segments.isEmpty ? .interrupted : .ready)
            }
            phase = .idle
        } catch { await failCapture(error) }
    }

    func clearError() { errorMessage = nil }

    private func authorizeDevices(_ options: CaptureOptions, operation: UUID) async throws {
        if options.capturesMicrophone { try await authorize(.audio, label: "Microphone") }
        guard epoch == operation else { throw CancellationError() }
        if options.cameraEnabled { try await authorize(.video, label: "Camera") }
    }

    private func authorize(_ type: AVMediaType, label: String) async throws {
        let status = AVCaptureDevice.authorizationStatus(for: type)
        let granted: Bool
        if status == .notDetermined { granted = await AVCaptureDevice.requestAccess(for: type) }
        else { granted = status == .authorized }
        guard granted else {
            throw CaptureError.message("\(label) access is off. Allow Framelet in System Settings → Privacy & Security, or turn \(label.lowercased()) off for this recording.")
        }
    }

    private func beginSegment(filter: SCContentFilter, operation: UUID) async throws {
        guard let project, project.segments.count < 500, project.clips.count < 1000 else {
            throw CaptureError.message("This recording has reached its segment limit. Stop it and start a new recording.")
        }
        let id = UUID()
        let screenPath = "segments/\(id.uuidString)-screen.mp4"
        let cameraPath = project.options.cameraEnabled ? "segments/\(id.uuidString)-camera.mov" : nil
        let screenURL = try library.newMediaURL(projectID: project.id, path: screenPath)
        let cameraURL = try cameraPath.map { try library.newMediaURL(projectID: project.id, path: $0) }
        guard !FileManager.default.fileExists(atPath: screenURL.path),
              cameraURL.map({ !FileManager.default.fileExists(atPath: $0.path) }) ?? true else {
            throw CaptureError.message("A new recording file already exists. Its contents were left unchanged.")
        }
        let changed: @Sendable () -> Void = { [weak self] in
            Task { @MainActor [weak self] in self?.resourcesChanged() }
        }
        let failed: @Sendable (String) -> Void = { [weak self] message in
            Task { @MainActor [weak self] in await self?.unexpectedFailure(segmentID: id, message: message) }
        }
        let screen = try ScreenRecording(filter: filter, configuration: streamConfiguration(filter, options: project.options),
                                         outputURL: screenURL, changed: changed, failed: failed)
        let camera = cameraURL == nil ? nil : CameraRecorder(changed: changed, failed: failed)
        let segment = CaptureSegment(id: id, screenPath: screenPath, cameraPath: cameraPath, screen: screen, camera: camera)
        active = segment
        resourcesChanged()
        if let camera { try await camera.prepare(deviceID: project.options.cameraDeviceID) }
        guard epoch == operation else { throw CancellationError() }
        cameraSession = camera?.session
        let cameraStart: Task<Double, Error>? = if let camera, let cameraURL {
            Task { try await camera.start(to: cameraURL) }
        } else { nil }
        do {
            segment.screenHost = try await screen.start()
            if let cameraStart { segment.cameraHost = try await cameraStart.value }
            guard epoch == operation else { throw CancellationError() }
        } catch {
            cameraStart?.cancel()
            throw error
        }
        resourcesChanged()
    }

    private func streamConfiguration(_ filter: SCContentFilter, options: CaptureOptions) throws -> SCStreamConfiguration {
        let pixelWidth = filter.contentRect.width * CGFloat(filter.pointPixelScale)
        let pixelHeight = filter.contentRect.height * CGFloat(filter.pointPixelScale)
        guard pixelWidth.isFinite, pixelHeight.isFinite, pixelWidth >= 2, pixelHeight >= 2 else {
            throw CaptureError.message("The selected source has no usable dimensions. Choose another display or window.")
        }
        let scale = min(1, min(1920 / pixelWidth, 1080 / pixelHeight))
        let configuration = SCStreamConfiguration()
        configuration.width = max(2, Int((pixelWidth * scale / 2).rounded(.down)) * 2)
        configuration.height = max(2, Int((pixelHeight * scale / 2).rounded(.down)) * 2)
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: 30)
        configuration.queueDepth = 3
        configuration.pixelFormat = kCVPixelFormatType_32BGRA
        configuration.captureDynamicRange = .SDR
        configuration.preservesAspectRatio = true
        configuration.scalesToFit = true
        configuration.showsCursor = options.showsCursor
        configuration.capturesAudio = options.capturesSystemAudio
        configuration.excludesCurrentProcessAudio = true
        configuration.captureMicrophone = options.capturesMicrophone
        if options.capturesMicrophone { configuration.microphoneCaptureDeviceID = options.microphoneDeviceID }
        return configuration
    }

    private func finishActiveSegment() async throws {
        guard let segment = active, var project else { return }
        try await stopResources(segment)
        let screenURL = try library.mediaURL(projectID: project.id, path: segment.screenPath)
        let duration = try await videoDuration(screenURL)
        guard let screenHost = segment.screenHost, screenHost.isFinite else {
            throw CaptureError.message("The screen recording has no valid timing anchor. Partial files have been retained.")
        }
        var offset: Double?
        if let path = segment.cameraPath {
            let cameraURL = try library.mediaURL(projectID: project.id, path: path)
            _ = try await videoDuration(cameraURL)
            guard let cameraHost = segment.cameraHost, cameraHost.isFinite else {
                throw CaptureError.message("The camera recording has no valid timing anchor. Partial files have been retained.")
            }
            offset = cameraHost - screenHost
            guard offset?.isFinite == true else { throw RecordingValidationError.invalidTiming }
        }
        project.segments.append(RecordingSegment(id: segment.id, screenPath: segment.screenPath,
                                                cameraPath: segment.cameraPath, cameraOffsetSeconds: offset,
                                                durationSeconds: duration))
        project.clips.append(RecordingClip(segmentID: segment.id, trimEndSeconds: duration))
        project.updatedAt = Date()
        // Keep the in-memory sealed result if an atomic manifest save fails.
        self.project = project
        active = nil
        cameraSession = nil
        elapsedSeconds = project.segments.reduce(0) { $0 + $1.durationSeconds }
        resourcesChanged()
        try library.save(project)
    }

    private func videoDuration(_ url: URL) async throws -> Double {
        let completion = RecordingCompletion<Double>()
        Task {
            do {
                let asset = AVURLAsset(url: url)
                guard let track = try await asset.loadTracks(withMediaType: .video).first else {
                    throw CaptureError.message("A recording file has no readable video track. Its original file has been retained.")
                }
                let range = try await track.load(.timeRange)
                guard range.start.seconds.isFinite, range.duration.seconds.isFinite, range.duration.seconds > 0 else {
                    throw RecordingValidationError.invalidTiming
                }
                completion.resolve(.success(range.duration.seconds))
            } catch { completion.resolve(.failure(error)) }
        }
        return try await completion.wait(seconds: 15, operation: "Reading the finished recording")
    }

    private func stopResources(_ segment: CaptureSegment) async throws {
        async let screenError = stopScreen(segment.screen)
        async let cameraError = stopCamera(segment.camera)
        let errors = await [screenError, cameraError].compactMap { $0 }
        resourcesChanged()
        if !errors.isEmpty { throw CaptureError.message(errors.joined(separator: "\n")) }
    }

    private func stopScreen(_ screen: ScreenRecording) async -> String? {
        do { try await screen.stopAndWait(); return nil }
        catch { return error.localizedDescription }
    }
    private func stopCamera(_ camera: CameraRecorder?) async -> String? {
        do { try await camera?.stopAndWait(); return nil }
        catch { return error.localizedDescription }
    }

    private func saveStatus(_ status: RecordingStatus) throws {
        guard var project else { return }
        project.status = status
        project.updatedAt = Date()
        self.project = project
        try library.save(project)
    }

    private func failCapture(_ error: Error) async {
        phase = .stopping
        countdownRemaining = 0
        elapsedTask?.cancel()
        var message = error is CancellationError ? "Recording was cancelled. Partial files have been retained." : error.localizedDescription
        if let segment = active {
            do { try await stopResources(segment) }
            catch { message += "\n" + error.localizedDescription }
            retiring.append(segment)
            active = nil
        }
        cameraSession = nil
        if var project {
            project.status = .failed
            project.lastError = message
            project.updatedAt = Date()
            self.project = project
            do { try library.save(project) }
            catch { message += "\nThe recording manifest could not be saved. Its package and original media remain on disk." }
        }
        resourcesChanged()
        errorMessage = message
        phase = .failed
    }

    private func unexpectedFailure(segmentID: UUID, message: String) async {
        guard phase == .starting || phase == .recording, active?.id == segmentID else { return }
        epoch = UUID()
        await failCapture(CaptureError.message(message))
    }

    private func resourcesChanged() {
        retiring.removeAll { !$0.hasUnfinishedCapture }
        hasUnfinishedCapture = active?.hasUnfinishedCapture == true || retiring.contains { $0.hasUnfinishedCapture }
    }

    private func startElapsedUpdates() {
        elapsedTask?.cancel()
        elapsedTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, self.phase == .recording, let anchor = self.active?.screenHost else { return }
                let sealed = self.project?.segments.reduce(0) { $0 + $1.durationSeconds } ?? 0
                let now = CMClockGetTime(CMClockGetHostTimeClock()).seconds
                if now.isFinite { self.elapsedSeconds = sealed + max(0, now - anchor) }
                try? await Task.sleep(nanoseconds: 250_000_000)
            }
        }
    }
}
