import Foundation

public enum RecordingValidationError: LocalizedError, Equatable {
    case invalidManifest, unsafePath, invalidTiming, invalidClip, invalidPresentation, emptyTimeline
    public var errorDescription: String? {
        switch self {
        case .invalidManifest: "This recording's manifest is invalid. Its original files have been retained."
        case .unsafePath: "This recording refers to a file outside its own package."
        case .invalidTiming: "A segment has missing or invalid media timing."
        case .invalidClip: "A clip's trim range is outside its source segment."
        case .invalidPresentation: "The canvas settings are outside their supported range."
        case .emptyTimeline: "Add at least one recorded clip before exporting."
        }
    }
}

public func isSafeRecordingPath(_ path: String) -> Bool {
    let parts = path.split(separator: "/", omittingEmptySubsequences: false)
    return parts.count == 2 && parts[0] == "segments" && !parts[1].isEmpty
        && parts.allSatisfy { $0 != "." && $0 != ".." && !$0.contains("\\") }
        && (path.hasSuffix(".mp4") || path.hasSuffix(".mov"))
}

public func validateRecording(_ project: RecordingProject) throws {
    guard project.schemaVersion == 1, !project.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
          project.title.count <= 200, project.segments.count <= 500, project.clips.count <= 1000,
          Set(project.segments.map(\.id)).count == project.segments.count,
          Set(project.clips.map(\.id)).count == project.clips.count else { throw RecordingValidationError.invalidManifest }
    for segment in project.segments {
        guard isSafeRecordingPath(segment.screenPath), segment.cameraPath.map(isSafeRecordingPath) ?? true else { throw RecordingValidationError.unsafePath }
        guard segment.durationSeconds.isFinite, segment.durationSeconds > 0,
              segment.cameraPath == nil || segment.cameraOffsetSeconds?.isFinite == true,
              segment.cameraPath != nil || segment.cameraOffsetSeconds == nil else { throw RecordingValidationError.invalidTiming }
    }
    for clip in project.clips {
        guard let segment = project.segments.first(where: { $0.id == clip.segmentID }),
              clip.trimStartSeconds.isFinite, clip.trimEndSeconds.isFinite,
              clip.trimStartSeconds >= 0, clip.trimEndSeconds > clip.trimStartSeconds,
              clip.trimEndSeconds <= segment.durationSeconds + 0.001 else { throw RecordingValidationError.invalidClip }
    }
    let style = project.presentation
    guard style.cameraScale.isFinite, (0.12...0.4).contains(style.cameraScale),
          style.inset.isFinite, (0...0.1).contains(style.inset) else { throw RecordingValidationError.invalidPresentation }
}

public struct TimelineSlice: Equatable, Sendable {
    public var clipID: UUID
    public var segment: RecordingSegment
    public var sourceStartSeconds: Double
    public var durationSeconds: Double
    public var timelineStartSeconds: Double
}

public func recordingTimeline(_ project: RecordingProject) throws -> [TimelineSlice] {
    try validateRecording(project)
    guard !project.clips.isEmpty else { throw RecordingValidationError.emptyTimeline }
    var cursor: Double = 0
    return project.clips.map { clip in
        let segment = project.segments.first { $0.id == clip.segmentID }!
        let result = TimelineSlice(clipID: clip.id, segment: segment, sourceStartSeconds: clip.trimStartSeconds,
                                   durationSeconds: clip.durationSeconds, timelineStartSeconds: cursor)
        cursor += clip.durationSeconds
        return result
    }
}

public struct CameraOverlap: Equatable, Sendable {
    public var sourceStartSeconds: Double
    public var timelineStartSeconds: Double
    public var durationSeconds: Double
}

public func cameraOverlap(slice: TimelineSlice, cameraDurationSeconds: Double) throws -> CameraOverlap? {
    guard slice.segment.cameraPath != nil else { return nil }
    guard let offset = slice.segment.cameraOffsetSeconds, offset.isFinite,
          cameraDurationSeconds.isFinite, cameraDurationSeconds > 0 else { throw RecordingValidationError.invalidTiming }
    let visibleStart = max(slice.sourceStartSeconds, offset)
    let visibleEnd = min(slice.sourceStartSeconds + slice.durationSeconds, offset + cameraDurationSeconds)
    guard visibleEnd > visibleStart else { return nil }
    return CameraOverlap(sourceStartSeconds: visibleStart - offset,
                         timelineStartSeconds: slice.timelineStartSeconds + visibleStart - slice.sourceStartSeconds,
                         durationSeconds: visibleEnd - visibleStart)
}
