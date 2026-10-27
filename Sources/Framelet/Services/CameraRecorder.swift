import Foundation
import AVFoundation
import CoreMedia
import FrameletCore

/// Video-only camera sidecar. System and microphone audio belong to SCStream.
final class CameraRecorder: NSObject, AVCaptureFileOutputDelegate, AVCaptureFileOutputRecordingDelegate, @unchecked Sendable {
    let session = AVCaptureSession()
    private let output = AVCaptureMovieFileOutput()
    private let queue = DispatchQueue(label: "Framelet.camera.session")
    private let lock = NSLock()
    private let changed: @Sendable () -> Void
    private let failed: @Sendable (String) -> Void
    private let firstFrame = RecordingCompletion<Double>()
    private let recordingStarted = RecordingCompletion<Void>()
    private let recordingFinished = RecordingCompletion<Void>()
    private let sessionShutdown = RecordingCompletion<Void>()
    private var pendingURL: URL?
    private var startInvoked = false
    private var startCallFinished = false
    private var stopRequested = false
    private var sessionStopped = true
    private var finishAcknowledged = false

    var hasUnfinishedCapture: Bool {
        lock.lock(); defer { lock.unlock() }
        return !sessionStopped || (startInvoked && !finishAcknowledged)
    }

    init(changed: @escaping @Sendable () -> Void, failed: @escaping @Sendable (String) -> Void) {
        self.changed = changed; self.failed = failed
        super.init()
    }

    func prepare(deviceID: String?) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                do {
                    let device: AVCaptureDevice?
                    if let deviceID, !deviceID.isEmpty { device = AVCaptureDevice(uniqueID: deviceID) }
                    else { device = AVCaptureDevice.default(for: .video) }
                    guard let device, device.hasMediaType(.video) else {
                        throw CaptureError.message("The selected camera is unavailable. Choose another camera or turn Camera off.")
                    }
                    let input = try AVCaptureDeviceInput(device: device)
                    self.session.beginConfiguration()
                    defer { self.session.commitConfiguration() }
                    guard self.session.canAddInput(input), self.session.canAddOutput(self.output) else {
                        throw CaptureError.message("The selected camera cannot be used for this recording.")
                    }
                    // A camera device can expose more than one media port.
                    // Connect video explicitly so the sidecar never duplicates
                    // microphone audio from ScreenCaptureKit.
                    self.session.addInputWithNoConnections(input)
                    self.session.addOutputWithNoConnections(self.output)
                    let videoPorts = input.ports.filter { $0.mediaType == .video }
                    guard !videoPorts.isEmpty else {
                        throw CaptureError.message("The selected camera has no video output.")
                    }
                    let connection = AVCaptureConnection(inputPorts: videoPorts, output: self.output)
                    guard self.session.canAddConnection(connection) else {
                        throw CaptureError.message("The selected camera cannot create a video-only recording.")
                    }
                    self.session.addConnection(connection)
                    guard self.session.canSetSessionPreset(.inputPriority) else {
                        throw CaptureError.message("The camera cannot use a bounded recording format.")
                    }
                    self.session.sessionPreset = .inputPriority
                    let formats = device.formats.filter { format in
                        let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
                        return dimensions.width > 0 && dimensions.height > 0 && dimensions.width <= 1280 && dimensions.height <= 720
                            && format.videoSupportedFrameRateRanges.contains { $0.minFrameRate <= 30 && $0.maxFrameRate >= 30 }
                    }.sorted { lhs, rhs in
                        let a = CMVideoFormatDescriptionGetDimensions(lhs.formatDescription)
                        let b = CMVideoFormatDescriptionGetDimensions(rhs.formatDescription)
                        return Int64(a.width) * Int64(a.height) > Int64(b.width) * Int64(b.height)
                    }
                    guard let format = formats.first else {
                        throw CaptureError.message("The camera has no supported recording format at 30 fps and up to 1280 × 720.")
                    }
                    try device.lockForConfiguration()
                    device.activeFormat = format
                    device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 30)
                    device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 30)
                    device.unlockForConfiguration()
                    self.output.setOutputSettings([
                        AVVideoCodecKey: AVVideoCodecType.h264,
                        AVVideoColorPropertiesKey: [
                            AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
                            AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
                            AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
                        ],
                    ], for: connection)
                    self.output.delegate = self
                    self.output.movieFragmentInterval = CMTime(seconds: 5, preferredTimescale: 600)
                    continuation.resume()
                } catch { continuation.resume(throwing: error) }
            }
        }
    }

    func start(to url: URL) async throws -> Double {
        queue.async {
            self.lock.lock()
            guard !self.stopRequested else {
                self.lock.unlock()
                self.firstFrame.resolve(.failure(CancellationError()))
                return
            }
            self.pendingURL = url
            self.sessionStopped = false
            self.lock.unlock()
            self.changed()
            self.session.startRunning()
            if !self.session.isRunning {
                let error = CaptureError.message("The camera session did not start. Its partial files have been retained.")
                self.firstFrame.resolve(.failure(error))
                self.recordingStarted.resolve(.failure(error))
                self.lock.lock(); self.sessionStopped = true; self.lock.unlock()
                self.changed()
            }
        }
        let host = try await firstFrame.wait(seconds: 15, operation: "Receiving the first camera frame")
        try await recordingStarted.wait(seconds: 15, operation: "Starting the camera recording")
        return host
    }

    func captureOutputShouldProvideSampleAccurateRecordingStart(_ output: AVCaptureOutput) -> Bool { true }

    func captureOutput(_ output: AVCaptureFileOutput, didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard sampleBuffer.isValid,
              let format = CMSampleBufferGetFormatDescription(sampleBuffer),
              CMFormatDescriptionGetMediaType(format) == kCMMediaType_Video else { return }
        lock.lock()
        guard let url = pendingURL, !startInvoked, !stopRequested else { lock.unlock(); return }
        pendingURL = nil
        startInvoked = true
        lock.unlock()
        do {
            let host = try sampleHostSeconds(sampleBuffer, clock: session.synchronizationClock)
            // This call must remain inside the sample callback. The file output
            // guarantees this very video frame is the first one written.
            output.startRecording(to: url, recordingDelegate: self)
            firstFrame.resolve(.success(host))
            lock.lock(); startCallFinished = true; let shouldStop = stopRequested; lock.unlock()
            if shouldStop { queue.async { self.performStop() } }
        } catch {
            lock.lock(); finishAcknowledged = true; startCallFinished = true; let shouldStop = stopRequested; lock.unlock()
            firstFrame.resolve(.failure(error))
            recordingStarted.resolve(.failure(error))
            recordingFinished.resolve(.failure(error))
            failed("Camera timing was unavailable. Partial files have been retained.")
            changed()
            if shouldStop { queue.async { self.performStop() } }
        }
    }

    func captureOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL,
                       from connections: [AVCaptureConnection]) {
        recordingStarted.resolve(.success(()))
        lock.lock(); let shouldStop = stopRequested; lock.unlock()
        if shouldStop { queue.async { output.stopRecording() } }
    }

    func captureOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL,
                       from connections: [AVCaptureConnection], error: Error?) {
        lock.lock(); finishAcknowledged = true; let expected = stopRequested; lock.unlock()
        // AVFoundation may attach a nonfatal error to an otherwise valid file.
        let fileSucceeded = (error as NSError?)?.userInfo[AVErrorRecordingSuccessfullyFinishedKey] as? Bool
        if let error, fileSucceeded != true {
            recordingStarted.resolve(.failure(error))
            firstFrame.resolve(.failure(error))
            recordingFinished.resolve(.failure(error))
            if !expected { failed("The camera recording stopped unexpectedly. Partial files have been retained.") }
        } else {
            recordingFinished.resolve(.success(()))
            if !expected { failed("The camera recording ended before Stop. Partial files have been retained.") }
        }
        changed()
    }

    func stopAndWait() async throws {
        queue.async {
            self.lock.lock()
            self.stopRequested = true
            self.pendingURL = nil
            self.lock.unlock()
            self.performStop()
        }
        try await sessionShutdown.wait(operation: "Stopping the camera")
        try await recordingFinished.wait(operation: "Finishing the camera file")
    }

    /// Do not stop the session underneath the sample-accurate start call. If
    /// that call is in flight, its callback schedules this shutdown afterwards.
    private func performStop() {
        lock.lock()
        let hasFile = startInvoked
        let startInFlight = startInvoked && !startCallFinished
        lock.unlock()
        guard !startInFlight else { return }
        if output.isRecording { output.stopRecording() }
        if session.isRunning { session.stopRunning() }
        lock.lock(); sessionStopped = !session.isRunning; lock.unlock()
        if !hasFile { recordingFinished.resolve(.success(())) }
        firstFrame.resolve(.failure(CancellationError()))
        recordingStarted.resolve(.failure(CancellationError()))
        sessionShutdown.resolve(.success(()))
        changed()
    }
}
