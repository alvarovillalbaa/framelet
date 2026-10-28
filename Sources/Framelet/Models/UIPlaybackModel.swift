import AVFoundation
import Foundation
import FrameletCore
import Observation

@MainActor @Observable
final class UIPlaybackModel {
    let screenPlayer = AVPlayer()
    let cameraPlayer = AVPlayer()
    private(set) var isLoading = false
    private(set) var isPlaying = false
    private(set) var positionSeconds: Double = 0
    private(set) var durationSeconds: Double = 0
    private(set) var previewsRecording = false
    private(set) var cameraVisible = false
    private(set) var errorMessage: String?
    private(set) var cameraMessage: String?
    @ObservationIgnored private var observer: Any?
    @ObservationIgnored private var failureObserver: NSObjectProtocol?
    @ObservationIgnored private var endObserver: NSObjectProtocol?
    @ObservationIgnored private var statusObserver: NSKeyValueObservation?
    @ObservationIgnored private var recordingComposition: RecordingComposition?
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var seekGeneration = 0
    @ObservationIgnored private var isSeeking = false
    @ObservationIgnored private var sourceStart: Double = 0
    @ObservationIgnored private var cameraOrigin: Double = 0
    @ObservationIgnored private var cameraOverlapStart: Double = 0
    @ObservationIgnored private var overlap: CameraOverlap?
    @ObservationIgnored private var suspended = false

    func load(project: RecordingProject, clip: RecordingClip, library: RecordingLibrary) async {
        clear()
        guard !suspended, !Task.isCancelled else { return }
        let token = generation
        isLoading = true
        defer { finishLoading(token: token) }
        do {
            guard let slice = try recordingTimeline(project).first(where: { $0.clipID == clip.id }) else {
                throw UIEditError.missingClip
            }
            let url = try library.mediaURL(projectID: project.id, path: slice.segment.screenPath)
            let asset = AVURLAsset(url: url)
            let playable = try await asset.load(.isPlayable)
            guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
                throw RecordingValidationError.invalidTiming
            }
            let videoRange = try await videoTrack.load(.timeRange)
            let actualDuration = CMTimeGetSeconds(videoRange.duration)
            let screenOrigin = CMTimeGetSeconds(videoRange.start)
            guard playable, actualDuration.isFinite, actualDuration > 0, screenOrigin.isFinite,
                  clip.trimEndSeconds <= actualDuration + 1.0 / 600.0 else {
                throw RecordingValidationError.invalidTiming
            }
            guard generation == token, !Task.isCancelled else { return }
            sourceStart = screenOrigin + clip.trimStartSeconds
            durationSeconds = clip.durationSeconds
            let item = AVPlayerItem(asset: asset)
            item.forwardPlaybackEndTime = CMTime(seconds: screenOrigin + min(actualDuration, clip.trimEndSeconds),
                                                preferredTimescale: 600)
            screenPlayer.actionAtItemEnd = .pause
            observe(item: item, token: token,
                    failureMessage: "This clip could not be played. Its original files have been retained.")
            screenPlayer.replaceCurrentItem(with: item)
            let positioned = await screenPlayer.seek(to: CMTime(seconds: sourceStart, preferredTimescale: 600),
                                                     toleranceBefore: .zero, toleranceAfter: .zero)
            guard generation == token, !Task.isCancelled else { return }
            guard positioned else {
                failPlayback(item: item, token: token,
                    message: "This clip could not be positioned. Reload the preview to try again. Originals have been retained.")
                return
            }
            if let path = slice.segment.cameraPath {
                do {
                    let cameraURL = try library.mediaURL(projectID: project.id, path: path)
                    let asset = AVURLAsset(url: cameraURL)
                    let cameraPlayable = try await asset.load(.isPlayable)
                    guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
                        throw RecordingValidationError.invalidTiming
                    }
                    let cameraRange = try await videoTrack.load(.timeRange)
                    let cameraDuration = CMTimeGetSeconds(cameraRange.duration)
                    let origin = CMTimeGetSeconds(cameraRange.start)
                    guard cameraPlayable, origin.isFinite else { throw RecordingValidationError.invalidTiming }
                    let visible = try cameraOverlap(slice: slice, cameraDurationSeconds: cameraDuration)
                    guard generation == token, !Task.isCancelled else { return }
                    cameraPlayer.replaceCurrentItem(with: AVPlayerItem(asset: asset))
                    cameraPlayer.isMuted = true
                    cameraOrigin = origin
                    overlap = visible
                    cameraOverlapStart = (visible?.timelineStartSeconds ?? 0) - slice.timelineStartSeconds
                    synchronizeCamera(force: true)
                } catch {
                    guard generation == token, !Task.isCancelled else { return }
                    cameraMessage = "Camera playback is unavailable for this clip. Original files are retained."
                }
            }
        } catch {
            if generation == token, !Task.isCancelled {
                errorMessage = "This clip could not be opened: " + error.localizedDescription
            }
        }
    }

    func loadRecording(project: RecordingProject, library: RecordingLibrary) async {
        clear()
        previewsRecording = true
        guard !suspended, !Task.isCancelled else { return }
        let token = generation
        isLoading = true
        defer { finishLoading(token: token) }
        do {
            let composition = try await RecordingCompositionBuilder.build(
                project: project, packageURL: library.packageURL(for: project.id))
            let playable = try await composition.asset.load(.isPlayable)
            guard generation == token, !Task.isCancelled, !suspended else { return }
            let duration = composition.duration.seconds
            guard playable, duration.isFinite, duration > 0 else {
                throw RecordingValidationError.invalidTiming
            }
            // One assembled item owns the global clock, source audio and camera gaps.
            // Retain the snapshot and its source assets until this load is cleared.
            recordingComposition = composition
            durationSeconds = duration
            let item = AVPlayerItem(asset: composition.asset)
            item.videoComposition = composition.videoComposition
            item.audioMix = composition.audioMix
            item.forwardPlaybackEndTime = composition.duration
            screenPlayer.actionAtItemEnd = .pause
            observe(item: item, token: token,
                    failureMessage: "This recording could not be played. Its original files have been retained.")
            screenPlayer.replaceCurrentItem(with: item)
        } catch {
            if generation == token, !Task.isCancelled {
                errorMessage = "This recording could not be opened: " + error.localizedDescription
            }
        }
    }

    func togglePlayback() {
        if isPlaying { pause(); return }
        guard !suspended, !isLoading, errorMessage == nil, screenPlayer.currentItem != nil else { return }
        isPlaying = true
        if positionSeconds >= durationSeconds {
            seek(to: 0)
            return
        }
        if !isSeeking {
            screenPlayer.play()
            synchronizeCamera(force: true)
        }
    }

    func pause() {
        isPlaying = false
        screenPlayer.pause()
        cameraPlayer.pause()
    }

    func setSuspended(_ value: Bool) {
        guard suspended != value else { return }
        suspended = value
        if value { clear() }
    }

    func seek(to seconds: Double) {
        guard seconds.isFinite, !suspended, errorMessage == nil,
              let item = screenPlayer.currentItem else { return }
        seekGeneration += 1
        let request = seekGeneration
        let token = generation
        isSeeking = true
        positionSeconds = min(durationSeconds, max(0, seconds))
        screenPlayer.pause()
        cameraPlayer.pause()
        item.cancelPendingSeeks()
        screenPlayer.seek(to: CMTime(seconds: sourceStart + positionSeconds, preferredTimescale: 600),
                          toleranceBefore: .zero, toleranceAfter: .zero) { [weak self, weak item] completed in
            Task { @MainActor in
                guard let self, let item, self.generation == token,
                      self.seekGeneration == request, self.screenPlayer.currentItem === item else { return }
                self.isSeeking = false
                guard !self.suspended else { return }
                guard completed else {
                    self.failPlayback(item: item, token: token,
                        message: "The playback position could not be changed. Reload the preview to try again. Originals have been retained.")
                    return
                }
                if self.isPlaying { self.screenPlayer.play() }
                self.synchronizeCamera(force: true)
            }
        }
    }

    func clear() {
        generation += 1
        seekGeneration += 1
        pause()
        isSeeking = false
        screenPlayer.currentItem?.cancelPendingSeeks()
        cameraPlayer.currentItem?.cancelPendingSeeks()
        if let observer { screenPlayer.removeTimeObserver(observer) }
        observer = nil
        if let failureObserver { NotificationCenter.default.removeObserver(failureObserver) }
        failureObserver = nil
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        endObserver = nil
        statusObserver?.invalidate()
        statusObserver = nil
        screenPlayer.replaceCurrentItem(with: nil)
        cameraPlayer.replaceCurrentItem(with: nil)
        recordingComposition = nil
        previewsRecording = false
        sourceStart = 0
        cameraOverlapStart = 0
        overlap = nil
        cameraOrigin = 0
        cameraVisible = false
        isLoading = false
        durationSeconds = 0
        positionSeconds = 0
        errorMessage = nil
        cameraMessage = nil
    }

    private func finishLoading(token: Int) {
        guard generation == token else { return }
        if Task.isCancelled { clear() }
        else { isLoading = false }
    }

    private func observe(item: AVPlayerItem, token: Int, failureMessage: String) {
        observer = screenPlayer.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.05, preferredTimescale: 600), queue: .main
        ) { [weak self, weak item] _ in
            Task { @MainActor in
                guard let self, let item, self.generation == token,
                      self.screenPlayer.currentItem === item, !self.isSeeking else { return }
                let sourceTime = CMTimeGetSeconds(self.screenPlayer.currentTime())
                guard sourceTime.isFinite else { return }
                self.positionSeconds = min(self.durationSeconds, max(0, sourceTime - self.sourceStart))
                self.synchronizeCamera(force: false)
            }
        }
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main
        ) { [weak self, weak item] _ in
            Task { @MainActor in
                guard let self, let item, self.generation == token,
                      self.screenPlayer.currentItem === item, !self.isSeeking else { return }
                let actualTime = CMTimeGetSeconds(self.screenPlayer.currentTime())
                let endTime = CMTimeGetSeconds(item.forwardPlaybackEndTime)
                let tolerance = min(1.0 / 600.0, max(0, endTime - self.sourceStart) / 2)
                guard actualTime.isFinite, endTime.isFinite,
                      actualTime >= endTime - tolerance else { return }
                self.pause()
                self.positionSeconds = self.durationSeconds
                self.synchronizeCamera(force: false)
            }
        }
        failureObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime, object: item, queue: .main
        ) { [weak self, weak item] _ in
            Task { @MainActor in
                guard let self, let item, self.generation == token,
                      self.screenPlayer.currentItem === item else { return }
                self.failPlayback(item: item, token: token, message: failureMessage)
            }
        }
        statusObserver = item.observe(\.status, options: [.initial, .new]) { [weak self] observed, _ in
            guard observed.status == .failed else { return }
            Task { @MainActor [weak self, weak observed] in
                guard let self, let observed, self.generation == token,
                      self.screenPlayer.currentItem === observed else { return }
                self.failPlayback(item: observed, token: token, message: failureMessage)
            }
        }
    }

    private func failPlayback(item: AVPlayerItem, token: Int, message: String) {
        guard generation == token, screenPlayer.currentItem === item else { return }
        let wasRecording = previewsRecording
        clear()
        previewsRecording = wasRecording
        errorMessage = message
    }

    private func synchronizeCamera(force: Bool) {
        guard let overlap, cameraPlayer.currentItem != nil,
              positionSeconds >= cameraOverlapStart,
              positionSeconds < cameraOverlapStart + overlap.durationSeconds else {
            cameraVisible = false
            cameraPlayer.pause()
            return
        }
        let wasVisible = cameraVisible
        cameraVisible = true
        let desired = cameraOrigin + overlap.sourceStartSeconds + positionSeconds - cameraOverlapStart
        let current = CMTimeGetSeconds(cameraPlayer.currentTime())
        if force || !wasVisible || !current.isFinite || abs(current - desired) > 0.15 {
            cameraPlayer.seek(to: CMTime(seconds: desired, preferredTimescale: 600),
                              toleranceBefore: .zero, toleranceAfter: .zero)
        }
        if isPlaying && !suspended { cameraPlayer.play() }
        else { cameraPlayer.pause() }
    }
}
