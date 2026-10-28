import AVFoundation
import CoreGraphics
import Foundation
import FrameletCore
import XCTest
@testable import Framelet

@MainActor
final class RecordingCompositionTests: XCTestCase {
    func testOrderedTrimmedAndDuplicatedClipsBecomeActualNativeSegmentMappings() async throws {
        let fixture = try await PlaybackMediaFixture.make()
        defer { clean(fixture) }
        var project = fixture.project
        let first = project.clips[0], second = project.clips[1]
        project.clips = [
            RecordingClip(segmentID: second.segmentID, trimStartSeconds: 0.3, trimEndSeconds: 0.9),
            first,
            RecordingClip(segmentID: first.segmentID, trimStartSeconds: 0.2, trimEndSeconds: 0.5),
        ]
        var progress: [Double] = []
        let built = try await build(project, fixture: fixture) { progress.append($0) }
        let tracks = try await PlaybackMediaFixture.wait { try await built.asset.loadTracks(withMediaType: .video) }
        let screen = try XCTUnwrap(tracks.first as? AVCompositionTrack)
        let segments = screen.segments.filter { !$0.isEmpty }
        XCTAssertEqual(segments.count, 3)
        let expected = [(fixture.secondScreenURL, 0.3, 0.0, 0.6), (fixture.firstScreenURL, 0.1, 0.6, 0.6),
                        (fixture.firstScreenURL, 0.2, 1.2, 0.3)]
        for (segment, value) in zip(segments, expected) {
            XCTAssertEqual(segment.sourceURL?.standardizedFileURL, value.0.standardizedFileURL)
            XCTAssertEqual(segment.timeMapping.source.start.seconds, value.1, accuracy: 0.00001)
            XCTAssertEqual(segment.timeMapping.target.start.seconds, value.2, accuracy: 0.00001)
            XCTAssertEqual(segment.timeMapping.target.duration.seconds, value.3, accuracy: 0.00001)
        }
        XCTAssertEqual(built.duration.seconds, 1.5, accuracy: 0.00001)
        XCTAssertNil(built.audioMix, "The authored files contain video only.")
        XCTAssertEqual(progress.first, 0); XCTAssertEqual(progress.last, 1)
        XCTAssertTrue(progress.allSatisfy { $0.isFinite && (0...1).contains($0) })
        XCTAssertTrue(zip(progress, progress.dropFirst()).allSatisfy { pair in pair.0 <= pair.1 })
    }

    func testNativeCompositorDecodesDifferentAuthoredColorsAcrossTheEditedBoundary() async throws {
        let fixture = try await PlaybackMediaFixture.make()
        defer { clean(fixture) }
        let built = try await build(fixture.project, fixture: fixture)
        let first = try await sample(built, at: 0.2)
        let second = try await sample(built, at: 0.8)
        XCTAssertGreaterThan(first.red, first.blue + 80)
        XCTAssertGreaterThan(first.red, first.green + 80)
        XCTAssertGreaterThan(second.blue, second.red + 80)
        XCTAssertGreaterThan(second.blue, second.green + 80)
        XCTAssertEqual(built.duration.seconds, 1.4, accuracy: 0.00001)
    }

    func testPositiveCameraOffsetCreatesAnActualLeadingGapAndThenAnOverlay() async throws {
        let fixture = try await PlaybackMediaFixture.make()
        defer { clean(fixture) }
        var project = cameraProject(fixture, offset: 0.4)
        project.presentation.cameraMirrored = false
        let built = try await build(project, fixture: fixture)
        XCTAssertEqual(try instruction(built, at: 0.1).layerInstructions.count, 1)
        XCTAssertEqual(try instruction(built, at: 0.5).layerInstructions.count, 2)
        let segments = try await cameraSegments(built, fixture: fixture)
        XCTAssertEqual(segments.count, 1)
        let segment = try XCTUnwrap(segments.first)
        XCTAssertEqual(segment.timeMapping.target.start.seconds, 0.3, accuracy: 0.00001)
        XCTAssertEqual(segment.timeMapping.source.start.seconds, 0, accuracy: 0.00001)
    }

    func testNegativeCameraOffsetUsesLaterSourceFramesAndLeavesTheActualEndingGap() async throws {
        let fixture = try await PlaybackMediaFixture.make()
        defer { clean(fixture) }
        let built = try await build(cameraProject(fixture, offset: -0.4), fixture: fixture)
        XCTAssertEqual(try instruction(built, at: 0.1).layerInstructions.count, 2)
        XCTAssertEqual(try instruction(built, at: 0.85).layerInstructions.count, 1)
        let segments = try await cameraSegments(built, fixture: fixture)
        let segment = try XCTUnwrap(segments.first)
        XCTAssertEqual(segment.timeMapping.target.start.seconds, 0, accuracy: 0.00001)
        XCTAssertEqual(segment.timeMapping.source.start.seconds, 0.5, accuracy: 0.00001)
        XCTAssertLessThan(CMTimeRangeGetEnd(segment.timeMapping.target).seconds, 0.8)
    }

    func testUnsafeMissingAndInvalidSourcesFailWithoutDeletingTheOwnedOriginals() async throws {
        let fixture = try await PlaybackMediaFixture.make()
        defer { clean(fixture) }
        let originals = try [fixture.firstScreenURL, fixture.secondScreenURL, fixture.cameraURL].map { try Data(contentsOf: $0) }
        var unsafe = fixture.project; unsafe.segments[0].screenPath = "../outside.mp4"
        await expectBuildFailure(unsafe, fixture: fixture, expectedValidation: .unsafePath)
        var missing = fixture.project
        missing.segments[1].screenPath = "segments/" + UUID().uuidString + "-missing.mp4"
        await expectBuildFailure(missing, fixture: fixture)
        let invalidName = UUID().uuidString + "-invalid.mp4"
        let invalidURL = fixture.library.packageURL(for: fixture.project.id).appendingPathComponent("segments/" + invalidName)
        let invalid = Data("Authored invalid media; never captured content.".utf8)
        try invalid.write(to: invalidURL, options: .withoutOverwriting)
        var malformed = fixture.project; malformed.segments[0].screenPath = "segments/" + invalidName
        await expectBuildFailure(malformed, fixture: fixture)
        XCTAssertEqual(try Data(contentsOf: invalidURL), invalid)
        for (url, bytes) in zip([fixture.firstScreenURL, fixture.secondScreenURL, fixture.cameraURL], originals) {
            XCTAssertEqual(try Data(contentsOf: url), bytes)
        }
    }

    func testCancellingAnInFlightNativeBuildCannotReturnACompletedCompositionOrLateProgress() async throws {
        let fixture = try await PlaybackMediaFixture.make()
        defer { clean(fixture) }
        for cancellationPoint in [0.5, 1.0] {
            var progress: [Double] = []
            do {
                _ = try await build(fixture.project, fixture: fixture) { value in
                    progress.append(value)
                    if value >= cancellationPoint { withUnsafeCurrentTask { $0?.cancel() } }
                }
                XCTFail("A cancelled native build returned a completed composition.")
            } catch { XCTAssertTrue(error is CancellationError) }
            XCTAssertTrue(progress.contains { $0 >= cancellationPoint })
            if cancellationPoint < 1 { XCTAssertFalse(progress.contains(1)) }
            let count = progress.count
            try await Task.sleep(for: .milliseconds(30))
            XCTAssertEqual(progress.count, count)
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: fixture.firstScreenURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: fixture.secondScreenURL.path))
    }

    private func build(_ project: RecordingProject, fixture: PlaybackMediaFixture,
                       progress: @escaping (Double) -> Void = { _ in }) async throws -> RecordingComposition {
        try await PlaybackMediaFixture.wait {
            try await RecordingCompositionBuilder.build(project: project,
                packageURL: fixture.library.packageURL(for: project.id), onProgress: progress)
        }
    }

    private func cameraProject(_ fixture: PlaybackMediaFixture, offset: Double) -> RecordingProject {
        var project = fixture.project
        project.segments[0].cameraPath = fixture.cameraPath
        project.segments[0].cameraOffsetSeconds = offset
        project.clips = [RecordingClip(segmentID: project.segments[0].id, trimStartSeconds: 0.1, trimEndSeconds: 1.0)]
        project.presentation.layout = .pictureInPicture
        return project
    }

    private func instruction(_ built: RecordingComposition, at seconds: Double) throws -> AVVideoCompositionInstruction {
        let time = CMTime(seconds: seconds, preferredTimescale: 600_000)
        return try XCTUnwrap(built.videoComposition.instructions.first {
            CMTimeCompare(time, $0.timeRange.start) >= 0 && CMTimeCompare(time, CMTimeRangeGetEnd($0.timeRange)) < 0
        } as? AVVideoCompositionInstruction)
    }

    private func cameraSegments(_ built: RecordingComposition, fixture: PlaybackMediaFixture) async throws -> [AVCompositionTrackSegment] {
        let tracks = try await PlaybackMediaFixture.wait { try await built.asset.loadTracks(withMediaType: .video) }
        var segments: [AVCompositionTrackSegment] = []
        for track in tracks {
            let compositionTrack = try XCTUnwrap(track as? AVCompositionTrack)
            segments.append(contentsOf: compositionTrack.segments.filter {
                !$0.isEmpty && $0.sourceURL?.standardizedFileURL == fixture.cameraURL.standardizedFileURL
            })
        }
        return segments
    }

    private func sample(_ built: RecordingComposition, at seconds: Double) async throws -> (red: Int, green: Int, blue: Int) {
        let generator = AVAssetImageGenerator(asset: built.asset)
        generator.videoComposition = built.videoComposition
        generator.maximumSize = CGSize(width: 128, height: 128)
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        let image = try await PlaybackMediaFixture.wait(onTimeout: { generator.cancelAllCGImageGeneration() }) {
            try await generator.image(at: CMTime(seconds: seconds, preferredTimescale: 600)).image
        }
        let crop = try XCTUnwrap(image.cropping(to: CGRect(x: CGFloat(image.width) / 3, y: CGFloat(image.height) / 3,
                                                          width: CGFloat(image.width) / 3, height: CGFloat(image.height) / 3)))
        var pixel = [UInt8](repeating: 0, count: 4)
        let rendered = pixel.withUnsafeMutableBytes { bytes -> Bool in
            guard let context = CGContext(data: bytes.baseAddress, width: 1, height: 1, bitsPerComponent: 8,
                bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo:
                    CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else { return false }
            context.draw(crop, in: CGRect(x: 0, y: 0, width: 1, height: 1))
            return true
        }
        XCTAssertTrue(rendered)
        return (Int(pixel[0]), Int(pixel[1]), Int(pixel[2]))
    }

    private func expectBuildFailure(_ project: RecordingProject, fixture: PlaybackMediaFixture,
                                    expectedValidation: RecordingValidationError? = nil) async {
        do { _ = try await build(project, fixture: fixture); XCTFail("Invalid source unexpectedly composed.") }
        catch {
            if let expectedValidation { XCTAssertEqual(error as? RecordingValidationError, expectedValidation) }
            XCTAssertFalse(error is CancellationError)
            if let fixtureError = error as? PlaybackFixtureError, case .timeout = fixtureError {
                XCTFail("The invalid-source check reached its harness deadline.")
            }
        }
    }

    private func clean(_ fixture: PlaybackMediaFixture) {
        do { try fixture.remove() }
        catch { XCTFail("Owned playback fixture cleanup failed.") }
    }
}
