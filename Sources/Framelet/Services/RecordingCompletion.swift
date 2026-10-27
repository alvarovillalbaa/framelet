import Foundation
import CoreMedia
import ScreenCaptureKit
import AVFoundation
import FrameletCore

enum CaptureError: LocalizedError {
    case message(String)
    var errorDescription: String? {
        switch self { case .message(let message): message }
    }
}

func sampleHostSeconds(_ sample: CMSampleBuffer, clock: CMClock?) throws -> Double {
    guard sample.isValid, let clock else {
        throw CaptureError.message("The capture clock was unavailable. The partial recording has been retained.")
    }
    let time = CMSyncConvertTime(CMSampleBufferGetPresentationTimeStamp(sample),
                                from: clock, to: CMClockGetHostTimeClock())
    guard time.isValid, time.seconds.isFinite else {
        throw CaptureError.message("Media timing was invalid. The partial recording has been retained.")
    }
    return time.seconds
}

/// Owns the stream and all of its callbacks until both OS shutdown and file
/// finalization are acknowledged, including after a UI operation times out.
final class ScreenRecording: NSObject, SCStreamOutput, SCStreamDelegate, SCRecordingOutputDelegate, @unchecked Sendable {
    let firstFrame = RecordingCompletion<Double>()
    let recordingStarted = RecordingCompletion<Void>()
    let recordingFinished = RecordingCompletion<Void>()
    private let lock = NSLock()
    private let sampleQueue = DispatchQueue(label: "Framelet.screen.samples")
    private var stream: SCStream!
    private var recordingOutput: SCRecordingOutput!
    private var startRequested = false
    private var captureStopped = true
    private var finishAcknowledged = false
    private var recordingWasStarted = false
    private var stopRequested = false
    private var stopAttempt: RecordingCompletion<Void>?
    private var firstHost: Double?
    private let changed: @Sendable () -> Void
    private let failed: @Sendable (String) -> Void

    var hasUnfinishedCapture: Bool {
        lock.lock(); defer { lock.unlock() }
        return startRequested && (!captureStopped || !finishAcknowledged)
    }

    init(filter: SCContentFilter, configuration: SCStreamConfiguration, outputURL: URL,
         changed: @escaping @Sendable () -> Void,
         failed: @escaping @Sendable (String) -> Void) throws {
        self.changed = changed; self.failed = failed
        super.init()
        stream = SCStream(filter: filter, configuration: configuration, delegate: self)
        let recordingConfiguration = SCRecordingOutputConfiguration()
        recordingConfiguration.outputURL = outputURL
        recordingConfiguration.outputFileType = .mp4
        recordingConfiguration.videoCodecType = .h264
        guard recordingConfiguration.availableOutputFileTypes.contains(.mp4),
              recordingConfiguration.availableVideoCodecTypes.contains(.h264) else {
            throw CaptureError.message("This Mac cannot record the supported MP4/H.264 format.")
        }
        recordingOutput = SCRecordingOutput(configuration: recordingConfiguration, delegate: self)
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: sampleQueue)
        // ScreenCaptureKit guarantees the first captured sample is written when
        // the recording output is attached before startCapture.
        try stream.addRecordingOutput(recordingOutput)
    }

    func start() async throws -> Double {
        markStartRequested()
        changed()
        let started = RecordingCompletion<Void>()
        stream.startCapture { error in
            if let error {
                self.lock.lock()
                self.captureStopped = true
                if !self.recordingWasStarted { self.finishAcknowledged = true }
                self.lock.unlock()
                started.resolve(.failure(error))
                self.recordingStarted.resolve(.failure(error))
                self.firstFrame.resolve(.failure(error))
                self.recordingFinished.resolve(.failure(error))
                self.changed()
            } else {
                started.resolve(.success(()))
                self.lock.lock(); let shouldStop = self.stopRequested; self.lock.unlock()
                if shouldStop { Task { try? await self.stopAndWait() } }
            }
        }
        try await started.wait(seconds: 15, operation: "Starting screen capture")
        try await recordingStarted.wait(seconds: 15, operation: "Starting the screen recording")
        return try await firstFrame.wait(seconds: 15, operation: "Receiving the first screen frame")
    }

    private func markStartRequested() {
        lock.lock(); startRequested = true; captureStopped = false; lock.unlock()
    }

    func stopAndWait() async throws {
        guard let state = prepareStop() else { return }
        let (alreadyStopped, attempt, shouldRequest) = state
        if alreadyStopped { attempt.resolve(.success(())) }
        if shouldRequest {
            stream.stopCapture { error in
                self.lock.lock()
                if error == nil { self.captureStopped = true }
                if self.stopAttempt === attempt { self.stopAttempt = nil }
                self.lock.unlock()
                if let error { attempt.resolve(.failure(error)) }
                else { attempt.resolve(.success(())) }
                self.changed()
            }
        }
        do { try await attempt.wait(operation: "Stopping screen capture") }
        catch {
            clearStopAttempt(attempt)
            throw error
        }
        try await recordingFinished.wait(operation: "Finishing the screen file")
    }

    private func prepareStop() -> (Bool, RecordingCompletion<Void>, Bool)? {
        lock.lock()
        defer { lock.unlock() }
        stopRequested = true
        if !startRequested { return nil }
        let alreadyStopped = captureStopped
        let attempt: RecordingCompletion<Void>
        let shouldRequest: Bool
        if let pending = stopAttempt {
            attempt = pending; shouldRequest = false
        } else {
            attempt = RecordingCompletion<Void>(); stopAttempt = attempt; shouldRequest = !alreadyStopped
        }
        return (alreadyStopped, attempt, shouldRequest)
    }

    private func clearStopAttempt(_ attempt: RecordingCompletion<Void>) {
        lock.lock()
        if stopAttempt === attempt { stopAttempt = nil }
        lock.unlock()
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        // This first complete callback is an API-informed alignment anchor.
        // The pre-attached recording output writes the first captured sample,
        // but Apple does not explicitly equate it with this complete callback.
        // First encoded frame/camera alignment remains a capture/export check.
        guard type == .screen, sampleBuffer.isValid,
              let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
              let status = attachments.first?[.status] as? Int,
              SCFrameStatus(rawValue: status) == .complete else { return }
        lock.lock(); let needsFirstFrame = firstHost == nil; lock.unlock()
        guard needsFirstFrame else { return }
        do {
            let host = try sampleHostSeconds(sampleBuffer, clock: stream.synchronizationClock)
            lock.lock(); firstHost = host; lock.unlock()
            firstFrame.resolve(.success(host))
        } catch { firstFrame.resolve(.failure(error)) }
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        lock.lock()
        captureStopped = true
        let expected = stopRequested
        let attempt = stopAttempt
        stopAttempt = nil
        lock.unlock()
        attempt?.resolve(.success(()))
        firstFrame.resolve(.failure(error))
        recordingStarted.resolve(.failure(error))
        changed()
        if !expected { failed("Screen capture stopped unexpectedly. Partial files have been retained.") }
    }

    func recordingOutputDidStartRecording(_ recordingOutput: SCRecordingOutput) {
        lock.lock(); recordingWasStarted = true; finishAcknowledged = false; lock.unlock()
        recordingStarted.resolve(.success(()))
        changed()
    }

    func recordingOutputDidFinishRecording(_ recordingOutput: SCRecordingOutput) {
        lock.lock(); finishAcknowledged = true; lock.unlock()
        recordingFinished.resolve(.success(()))
        changed()
    }

    func recordingOutput(_ recordingOutput: SCRecordingOutput, didFailWithError error: Error) {
        lock.lock(); finishAcknowledged = true; let expected = stopRequested; lock.unlock()
        recordingStarted.resolve(.failure(error))
        firstFrame.resolve(.failure(error))
        recordingFinished.resolve(.failure(error))
        changed()
        if !expected { failed("Writing the screen recording failed. Partial files have been retained.") }
    }
}
