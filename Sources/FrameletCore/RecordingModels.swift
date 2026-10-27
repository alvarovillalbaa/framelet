import Foundation

public enum RecordingStatus: String, Codable, Sendable {
    case recording, paused, ready, interrupted, failed
}

public struct CaptureOptions: Codable, Equatable, Sendable {
    public var capturesSystemAudio = false
    public var capturesMicrophone = false
    public var cameraEnabled = false
    public var showsCursor = true
    public var countdownSeconds = 3
    public var microphoneDeviceID: String? = nil
    public var cameraDeviceID: String? = nil
    public init() {}
}

public struct RecordingSegment: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var screenPath: String
    public var cameraPath: String?
    /// First written camera frame host time minus first written screen frame host time.
    public var cameraOffsetSeconds: Double?
    public var durationSeconds: Double

    public init(id: UUID, screenPath: String, cameraPath: String? = nil,
                cameraOffsetSeconds: Double? = nil, durationSeconds: Double) {
        self.id = id; self.screenPath = screenPath; self.cameraPath = cameraPath
        self.cameraOffsetSeconds = cameraOffsetSeconds; self.durationSeconds = durationSeconds
    }
}

public struct RecordingClip: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var segmentID: UUID
    public var trimStartSeconds: Double
    public var trimEndSeconds: Double
    public var durationSeconds: Double { trimEndSeconds - trimStartSeconds }
    public init(id: UUID = UUID(), segmentID: UUID, trimStartSeconds: Double = 0, trimEndSeconds: Double) {
        self.id = id; self.segmentID = segmentID
        self.trimStartSeconds = trimStartSeconds; self.trimEndSeconds = trimEndSeconds
    }
}

public enum OutputPreset: String, Codable, CaseIterable, Identifiable, Sendable {
    case landscape, portrait, square
    public var id: String { rawValue }
    public var title: String { switch self { case .landscape: "Landscape"; case .portrait: "Portrait"; case .square: "Square" } }
    public var width: Int { self == .landscape ? 1920 : 1080 }
    public var height: Int { self == .portrait ? 1920 : 1080 }
}

public enum CanvasLayout: String, Codable, CaseIterable, Identifiable, Sendable {
    case screenOnly, pictureInPicture, sideBySide
    public var id: String { rawValue }
    public var title: String { switch self { case .screenOnly: "Screen"; case .pictureInPicture: "Picture in picture"; case .sideBySide: "Side by side" } }
}

public enum CanvasBackground: String, Codable, CaseIterable, Identifiable, Sendable {
    case midnight, sand, forest
    public var id: String { rawValue }
    public var title: String { rawValue.capitalized }
    public var rgb: (Double, Double, Double) {
        switch self { case .midnight: (0.08, 0.10, 0.16); case .sand: (0.94, 0.90, 0.81); case .forest: (0.10, 0.23, 0.19) }
    }
}

public enum CameraCorner: String, Codable, CaseIterable, Identifiable, Sendable {
    case bottomRight, bottomLeft, topRight, topLeft
    public var id: String { rawValue }
    public var title: String {
        switch self { case .bottomRight: "Bottom right"; case .bottomLeft: "Bottom left"; case .topRight: "Top right"; case .topLeft: "Top left" }
    }
}

public struct NormalizedRect: Equatable, Sendable {
    /// Coordinates are normalized and measured from the canvas's top-left corner.
    public var x: Double; public var y: Double; public var width: Double; public var height: Double
    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x; self.y = y; self.width = width; self.height = height
    }
}

public struct PresentationSettings: Codable, Equatable, Sendable {
    public var preset: OutputPreset = .landscape
    public var layout: CanvasLayout = .screenOnly
    public var background: CanvasBackground = .midnight
    public var cameraCorner: CameraCorner = .bottomRight
    public var cameraScale: Double = 0.25
    public var cameraMirrored = true
    public var inset: Double = 0.04
    public init() {}

    public var screenRect: NormalizedRect {
        if layout == .sideBySide { return .init(x: inset, y: inset, width: 0.62 - inset, height: 1 - 2 * inset) }
        return .init(x: inset, y: inset, width: 1 - 2 * inset, height: 1 - 2 * inset)
    }
    public var cameraRect: NormalizedRect? {
        if layout == .screenOnly { return nil }
        if layout == .sideBySide { return .init(x: 0.65, y: inset, width: 0.35 - inset, height: 1 - 2 * inset) }
        let left = cameraCorner == .bottomLeft || cameraCorner == .topLeft
        let top = cameraCorner == .topLeft || cameraCorner == .topRight
        let height = min(0.4, cameraScale * Double(preset.width) / Double(preset.height) * 0.75)
        return .init(x: left ? inset : 1 - inset - cameraScale, y: top ? inset : 1 - inset - height,
                     width: cameraScale, height: height)
    }
}

public struct RecordingProject: Codable, Identifiable, Equatable, Sendable {
    public var schemaVersion = 1
    public var id: UUID
    public var title: String
    public var createdAt: Date
    public var updatedAt: Date
    public var status: RecordingStatus
    public var options: CaptureOptions
    public var segments: [RecordingSegment]
    public var clips: [RecordingClip]
    public var presentation: PresentationSettings
    public var lastError: String?
    public var durationSeconds: Double { clips.reduce(0) { $0 + $1.durationSeconds } }

    public init(id: UUID = UUID(), title: String, options: CaptureOptions = CaptureOptions(), now: Date = Date()) {
        self.id = id; self.title = title; self.createdAt = now; self.updatedAt = now
        self.status = .recording; self.options = options; self.segments = []; self.clips = []
        self.presentation = PresentationSettings()
        if options.cameraEnabled { self.presentation.layout = .pictureInPicture }
    }
}
