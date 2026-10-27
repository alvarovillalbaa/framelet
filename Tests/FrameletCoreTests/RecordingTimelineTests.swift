import Foundation
import XCTest
@testable import FrameletCore

final class RecordingTimelineTests: XCTestCase {
    private func example() -> RecordingProject {
        var project = RecordingProject(title: "Authored recording")
        project.status = .ready
        let first = RecordingSegment(id: UUID(), screenPath: "segments/first-screen.mp4", durationSeconds: 10)
        let second = RecordingSegment(id: UUID(), screenPath: "segments/second-screen.mp4",
            cameraPath: "segments/second-camera.mov", cameraOffsetSeconds: 2, durationSeconds: 8)
        project.segments = [first, second]
        project.clips = [RecordingClip(segmentID: first.id, trimStartSeconds: 2, trimEndSeconds: 6),
                         RecordingClip(segmentID: second.id, trimStartSeconds: 1, trimEndSeconds: 7)]
        return project
    }

    func testPausedGapsAreNotInsertedAndTrimmedClipsStayOrdered() throws {
        let slices = try recordingTimeline(example())
        XCTAssertEqual(slices.map(\.sourceStartSeconds), [2, 1])
        XCTAssertEqual(slices.map(\.durationSeconds), [4, 6])
        XCTAssertEqual(slices.map(\.timelineStartSeconds), [0, 4])
    }

    func testReorderedDuplicateClipsReferenceOriginalMediaWithoutCopying() throws {
        var project = example()
        let original = project.clips[0]
        project.clips = [project.clips[1], original,
            RecordingClip(segmentID: original.segmentID, trimStartSeconds: 3, trimEndSeconds: 5)]
        let slices = try recordingTimeline(project)
        XCTAssertEqual(slices.map(\.timelineStartSeconds), [0, 6, 10])
        XCTAssertEqual(slices[1].segment, slices[2].segment)
        XCTAssertEqual(project.segments.count, 2)
    }

    func testLateCameraStartsOnlyDuringItsOverlapAfterTrimming() throws {
        let slice = try recordingTimeline(example())[1]
        let overlap = try XCTUnwrap(cameraOverlap(slice: slice, cameraDurationSeconds: 5))
        XCTAssertEqual(overlap.sourceStartSeconds, 0)
        XCTAssertEqual(overlap.timelineStartSeconds, 5)
        XCTAssertEqual(overlap.durationSeconds, 5)
    }

    func testEarlyCameraSkipsItsLeadingFramesAndStopsAtItsRealEnd() throws {
        var project = example()
        project.segments[1].cameraOffsetSeconds = -2
        let slice = try recordingTimeline(project)[1]
        let overlap = try XCTUnwrap(cameraOverlap(slice: slice, cameraDurationSeconds: 7))
        XCTAssertEqual(overlap.sourceStartSeconds, 3)
        XCTAssertEqual(overlap.timelineStartSeconds, 4)
        XCTAssertEqual(overlap.durationSeconds, 4)
    }

    func testCameraOutsideClipProducesNoStalePicture() throws {
        var project = example()
        project.segments[1].cameraOffsetSeconds = 20
        XCTAssertNil(try cameraOverlap(slice: recordingTimeline(project)[1], cameraDurationSeconds: 2))
        XCTAssertNil(try cameraOverlap(slice: recordingTimeline(project)[0], cameraDurationSeconds: 2))
    }

    func testCameraPathRequiresARealFiniteTimingOffset() {
        let invalidValues: [Double?] = [nil, .nan, .infinity, -.infinity]
        for invalid in invalidValues {
            var project = example()
            project.segments[1].cameraOffsetSeconds = invalid
            XCTAssertThrowsError(try validateRecording(project))
        }
    }

    func testMalformedAndEscapingMediaPathsAreRejected() {
        for invalid in ["/private/user.mp4", "../user.mp4", "segments/../user.mp4", "segments/other/file.mp4",
                        "segments\\user.mp4", "segments//file.mp4", "segments/.", "segments/file.json"] {
            XCTAssertFalse(isSafeRecordingPath(invalid), invalid)
            var project = example()
            project.segments[0].screenPath = invalid
            XCTAssertThrowsError(try validateRecording(project))
        }
    }

    func testInvalidTrimsNeverReachTheExportTimeline() {
        for range in [(-1.0, 2.0), (2, 2), (4, 3), (0, 11), (.nan, 2), (0, .infinity)] {
            var project = example()
            project.clips[0].trimStartSeconds = range.0
            project.clips[0].trimEndSeconds = range.1
            XCTAssertThrowsError(try recordingTimeline(project))
        }
    }

    func testOrphanedAndDuplicateIdentitiesAreRejected() {
        var project = example()
        project.clips[0].segmentID = UUID()
        XCTAssertThrowsError(try validateRecording(project))
        project = example(); project.clips.append(project.clips[0])
        XCTAssertThrowsError(try validateRecording(project))
        project = example(); project.segments.append(project.segments[0])
        XCTAssertThrowsError(try validateRecording(project))
    }

    func testEmptyTimelineIsRecoverableButCannotExport() throws {
        let empty = RecordingProject(title: "Interrupted before first segment")
        XCTAssertNoThrow(try validateRecording(empty))
        XCTAssertThrowsError(try recordingTimeline(empty))
    }

    func testCanvasRectanglesRemainInsideEveryOutputPreset() throws {
        for preset in OutputPreset.allCases {
            for layout in CanvasLayout.allCases {
                for corner in CameraCorner.allCases {
                    var project = example()
                    project.presentation.preset = preset
                    project.presentation.layout = layout
                    project.presentation.cameraCorner = corner
                    try validateRecording(project)
                    for rect in [project.presentation.screenRect, project.presentation.cameraRect].compactMap({ $0 }) {
                        XCTAssertGreaterThanOrEqual(rect.x, 0); XCTAssertGreaterThanOrEqual(rect.y, 0)
                        XCTAssertGreaterThan(rect.width, 0); XCTAssertGreaterThan(rect.height, 0)
                        XCTAssertLessThanOrEqual(rect.x + rect.width, 1.000001)
                        XCTAssertLessThanOrEqual(rect.y + rect.height, 1.000001)
                    }
                }
            }
        }
    }

    func testInvalidCanvasValuesAndUnknownSchemaFailClosed() {
        var project = example()
        project.presentation.cameraScale = .nan
        XCTAssertThrowsError(try validateRecording(project))
        project = example(); project.presentation.inset = 0.5
        XCTAssertThrowsError(try validateRecording(project))
        project = example(); project.schemaVersion = 2
        XCTAssertThrowsError(try validateRecording(project))
    }

    func testManifestRoundTripPreservesSourcesEditsAndSignedOffset() throws {
        var project = example()
        project.segments[1].cameraOffsetSeconds = -0.275
        let restored = try JSONDecoder().decode(RecordingProject.self, from: JSONEncoder().encode(project))
        XCTAssertEqual(restored, project)
        XCTAssertEqual(try recordingTimeline(restored), try recordingTimeline(project))
    }
}
