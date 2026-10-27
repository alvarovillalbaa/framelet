import Foundation

enum CapturePhase: String, Equatable, Hashable, Sendable {
    case idle, choosing, countdown, starting, recording, pausing, paused, stopping, failed
}
