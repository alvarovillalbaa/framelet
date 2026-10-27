import Foundation
import FrameletCore

enum UIFormatters {
    static func duration(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "—" }
        let total = Int(min(seconds, 35_999_999))
        if total >= 3600 {
            return String(format: "%d:%02d:%02d", total / 3600, total / 60 % 60, total % 60)
        }
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    static func trimTime(_ seconds: Double) -> String {
        String(format: "%.2f", seconds)
    }

    static func editableSeconds(_ seconds: Double) -> String {
        String(seconds)
    }

    static func status(_ status: RecordingStatus) -> String {
        switch status {
        case .recording: "Recording"
        case .paused: "Paused"
        case .ready: "Ready"
        case .interrupted: "Interrupted"
        case .failed: "Needs attention"
        }
    }

    static func exportName(_ title: String) -> String {
        let cleaned = title.components(separatedBy: CharacterSet(charactersIn: "/:\\"))
            .joined(separator: "-").trimmingCharacters(in: .whitespacesAndNewlines)
        return String((cleaned.isEmpty ? "Recording" : cleaned).prefix(160)) + ".mp4"
    }
}
