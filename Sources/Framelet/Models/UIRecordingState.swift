import Foundation
import FrameletCore

extension CapturePhase {
    var uiTitle: String {
        switch self {
        case .idle: "Ready to record"
        case .choosing: "Choose a display or window"
        case .countdown: "Starting soon"
        case .starting: "Preparing recording"
        case .recording: "Recording"
        case .pausing: "Finishing this segment"
        case .paused: "Paused"
        case .stopping: "Finishing recording"
        case .failed: "Recording needs attention"
        }
    }
}

@MainActor
enum UIRecordingActions {
    static func hasCaptureWork(_ capture: CaptureCoordinator) -> Bool {
        capture.hasUnfinishedCapture ||
            [.countdown, .starting, .recording, .pausing, .paused, .stopping].contains(capture.phase)
    }

    static func canChoose(_ capture: CaptureCoordinator) -> Bool {
        !hasCaptureWork(capture) && (capture.phase == .idle || capture.phase == .failed)
    }

    static func canStart(_ capture: CaptureCoordinator) -> Bool {
        canChoose(capture) && capture.selectedSourceName != nil
    }

    static func canStop(_ capture: CaptureCoordinator) -> Bool {
        hasCaptureWork(capture) &&
            [.countdown, .starting, .recording, .paused, .failed].contains(capture.phase)
    }

    static func togglePause(_ capture: CaptureCoordinator) {
        if capture.phase == .recording {
            Task { await capture.pause() }
        } else if capture.phase == .paused {
            Task { await capture.resume() }
        }
    }
}

enum UICapturePreferences {
    private static let key = "Framelet.captureOptions.v1"
    static let hideWindowKey = "Framelet.hideWindowWhileRecording"

    static var hidesWindowWhileRecording: Bool {
        UserDefaults.standard.object(forKey: hideWindowKey) as? Bool ?? true
    }

    static func load() -> CaptureOptions {
        guard let data = UserDefaults.standard.data(forKey: key),
              var options = try? JSONDecoder().decode(CaptureOptions.self, from: data) else {
            return CaptureOptions()
        }
        if !(0...10).contains(options.countdownSeconds) { options.countdownSeconds = 3 }
        return options
    }

    static func save(_ options: CaptureOptions) {
        if let data = try? JSONEncoder().encode(options) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

enum UIEditError: LocalizedError {
    case busy, missingClip, changedRecording
    var errorDescription: String? {
        switch self {
        case .busy: "Finish recording or exporting before changing this recording."
        case .missingClip: "This clip is no longer in the recording. Select another clip."
        case .changedRecording: "The recording is no longer available in the library."
        }
    }
}
