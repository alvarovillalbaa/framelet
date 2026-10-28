import AVFoundation
import Foundation
import XCTest
@testable import Framelet
import FrameletCore

final class UIPlaybackModelTests: XCTestCase {
    private enum PlaybackCheckError: Error {
        case deadline(String)
        case playerUnavailable
    }

    @MainActor
    private func makeModel() -> UIPlaybackModel {
        let model = UIPlaybackModel()
        model.screenPlayer.isMuted = true
        model.cameraPlayer.isMuted = true
        return model
    }

    @MainActor
    private func waitUntil(_ description: String, timeout: Duration = .seconds(8),
                           condition: () -> Bool) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while !condition() {
            try Task.checkCancellation()
            guard clock.now < deadline else { throw PlaybackCheckError.deadline(description) }
            try await Task.sleep(for: .milliseconds(10))
        }
        guard clock.now < deadline else { throw PlaybackCheckError.deadline(description) }
    }

    @MainActor
    private func within<Value>(_ description: String, onTimeout: @escaping @MainActor () -> Void = {},
                               operation: @escaping @MainActor () async throws -> Value) async throws -> Value {
        do {
            return try await PlaybackMediaFixture.wait(timeout: .seconds(8), onTimeout: onTimeout, operation)
        } catch PlaybackFixtureError.timeout {
            throw PlaybackCheckError.deadline(description)
        }
    }

    @MainActor
    private func loadRecording(_ model: UIPlaybackModel, fixture: PlaybackMediaFixture,
                               project: RecordingProject? = nil) async throws {
        let snapshot = project ?? fixture.project
        try await within("recording load", onTimeout: { model.clear() }) {
            await model.loadRecording(project: snapshot, library: fixture.library)
        }
    }

    @MainActor
    private func readyItem(_ model: UIPlaybackModel) async throws -> AVPlayerItem {
        try await waitUntil("native item readiness") {
            model.errorMessage != nil || model.screenPlayer.currentItem?.status == .readyToPlay ||
                model.screenPlayer.currentItem?.status == .failed
        }
        guard model.errorMessage == nil, let item = model.screenPlayer.currentItem,
              item.status == .readyToPlay else { throw PlaybackCheckError.playerUnavailable }
        XCTAssertFalse(model.isLoading)
        return item
    }

    @MainActor
    private func waitForPosition(_ model: UIPlaybackModel, global: Double,
                                 source: Double? = nil) async throws {
        let native = source ?? global
        try await waitUntil("native seek completion") {
            let actual = model.screenPlayer.currentTime().seconds
            return actual.isFinite && abs(actual - native) < 0.025 &&
                abs(model.positionSeconds - global) < 0.025
        }
        XCTAssertNil(model.errorMessage)
    }

    @MainActor
    private func remove(_ fixture: PlaybackMediaFixture, model: UIPlaybackModel) {
        model.clear()
        do { try fixture.remove() }
        catch { XCTFail("The owned playback fixture could not be removed.") }
    }

    @MainActor
    func testLoadsFullOrderedCompositionAndRetainsPlayableItem() async throws {
        let fixture = try await PlaybackMediaFixture.make()
        let model = makeModel()
        defer { remove(fixture, model: model) }
        var edited = fixture.project
        edited.clips.swapAt(0, 1)
        try await loadRecording(model, fixture: fixture, project: edited)
        let item = try await readyItem(model)
        let asset = try XCTUnwrap(item.asset as? AVComposition)
        let tracks = try await within("assembled video tracks") {
            try await asset.loadTracks(withMediaType: .video)
        }
        XCTAssertEqual(tracks.count, 1)
        let track = try XCTUnwrap(tracks.first as? AVCompositionTrack)
        let segments = track.segments.filter { !$0.isEmpty }
        XCTAssertEqual(segments.count, 2)
        XCTAssertEqual(segments.compactMap(\.sourceURL).map { $0.standardizedFileURL },
                       [fixture.secondScreenURL.standardizedFileURL, fixture.firstScreenURL.standardizedFileURL])
        let first = try XCTUnwrap(segments.first)
        let second = try XCTUnwrap(segments.last)
        XCTAssertEqual(first.timeMapping.source.start.seconds, 0.2, accuracy: 1.0 / 600)
        XCTAssertEqual(first.timeMapping.target.start.seconds, 0, accuracy: 1.0 / 600)
        XCTAssertEqual(first.timeMapping.target.duration.seconds, 0.8, accuracy: 1.0 / 600)
        XCTAssertEqual(second.timeMapping.source.start.seconds, 0.1, accuracy: 1.0 / 600)
        XCTAssertEqual(second.timeMapping.target.start.seconds, 0.8, accuracy: 1.0 / 600)
        XCTAssertEqual(second.timeMapping.target.duration.seconds, 0.6, accuracy: 1.0 / 600)
        XCTAssertEqual(model.durationSeconds, 1.4, accuracy: 1.0 / 600)
        XCTAssertEqual(item.forwardPlaybackEndTime.seconds, 1.4, accuracy: 1.0 / 600)
        XCTAssertNotNil(item.videoComposition)
        XCTAssertTrue(model.previewsRecording)
        XCTAssertFalse(model.isPlaying)
        XCTAssertEqual(model.screenPlayer.rate, 0)
        XCTAssertNil(model.cameraPlayer.currentItem)
        XCTAssertFalse(model.cameraVisible)
        await Task.yield()
        XCTAssertTrue(model.screenPlayer.currentItem === item)
        XCTAssertEqual(item.status, .readyToPlay)
    }

    @MainActor
    func testGlobalSeekCrossesTheClipBoundaryAndCanReturnToTheFirstClip() async throws {
        let fixture = try await PlaybackMediaFixture.make()
        let model = makeModel()
        defer { remove(fixture, model: model) }
        try await loadRecording(model, fixture: fixture)
        _ = try await readyItem(model)
        model.seek(to: 0.95) // Beyond the first clip's 0.6-second timeline range.
        try await waitForPosition(model, global: 0.95)
        XCTAssertGreaterThan(model.screenPlayer.currentTime().seconds, 0.6)
        model.seek(to: 0.2)
        try await waitForPosition(model, global: 0.2)
        XCTAssertLessThan(model.screenPlayer.currentTime().seconds, 0.6)
        XCTAssertFalse(model.isPlaying)
        XCTAssertEqual(model.screenPlayer.rate, 0)
        XCTAssertEqual(model.durationSeconds, 1.4, accuracy: 1.0 / 600)
    }

    @MainActor
    func testNativeEndStopsPlaybackAndPlayRestartsFromTheBeginning() async throws {
        let fixture = try await PlaybackMediaFixture.make()
        let model = makeModel()
        defer { remove(fixture, model: model) }
        try await loadRecording(model, fixture: fixture)
        let item = try await readyItem(model)
        model.seek(to: model.durationSeconds - 0.3)
        try await waitForPosition(model, global: model.durationSeconds - 0.3)
        model.togglePlayback()
        XCTAssertTrue(model.isPlaying)
        try await waitUntil("native end-of-item acknowledgement") {
            !model.isPlaying && model.screenPlayer.rate == 0 &&
                abs(model.positionSeconds - model.durationSeconds) < 1.0 / 600
        }
        XCTAssertGreaterThanOrEqual(model.screenPlayer.currentTime().seconds,
                                    item.forwardPlaybackEndTime.seconds - 1.0 / 600)
        model.togglePlayback()
        try await waitUntil("native playback restart") {
            let actual = model.screenPlayer.currentTime().seconds
            return model.isPlaying && model.screenPlayer.rate > 0 && actual.isFinite &&
                actual > 0 && actual < 0.6 && model.positionSeconds < 0.6
        }
        XCTAssertNil(model.errorMessage)
        XCTAssertTrue(model.screenPlayer.isMuted)
        model.pause()
    }

    @MainActor
    func testCaptureSuspensionClearsMediaAndRequiresAnExplicitReload() async throws {
        let fixture = try await PlaybackMediaFixture.make()
        let model = makeModel()
        defer { remove(fixture, model: model) }
        try await loadRecording(model, fixture: fixture)
        _ = try await readyItem(model)
        model.togglePlayback()
        try await waitUntil("native playback before suspension") { model.screenPlayer.rate > 0 }
        model.setSuspended(true)
        XCTAssertNil(model.screenPlayer.currentItem)
        XCTAssertNil(model.cameraPlayer.currentItem)
        XCTAssertFalse(model.isPlaying)
        XCTAssertEqual(model.screenPlayer.rate, 0)
        XCTAssertEqual(model.durationSeconds, 0)
        model.togglePlayback()
        model.seek(to: 0.4)
        try await loadRecording(model, fixture: fixture)
        XCTAssertNil(model.screenPlayer.currentItem)
        XCTAssertFalse(model.isLoading)
        XCTAssertFalse(model.isPlaying)
        XCTAssertEqual(model.positionSeconds, 0)
        model.setSuspended(false)
        model.togglePlayback()
        XCTAssertNil(model.screenPlayer.currentItem)
        XCTAssertFalse(model.isPlaying)
        try await loadRecording(model, fixture: fixture)
        _ = try await readyItem(model)
        XCTAssertEqual(model.durationSeconds, 1.4, accuracy: 1.0 / 600)
        XCTAssertFalse(model.isPlaying)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fixture.firstScreenURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: fixture.secondScreenURL.path))
    }

    @MainActor
    func testClearAndClipReloadFenceTheOldNativeSeekCompletion() async throws {
        let fixture = try await PlaybackMediaFixture.make()
        let model = makeModel()
        defer { remove(fixture, model: model) }
        try await loadRecording(model, fixture: fixture)
        let previous = try await readyItem(model)
        model.seek(to: 0.95)
        model.clear() // Invalidate before the queued native seek callback can publish.
        XCTAssertNil(model.screenPlayer.currentItem)
        XCTAssertEqual(model.positionSeconds, 0)
        let clip = fixture.project.clips[1]
        try await within("selected clip reload", onTimeout: { model.clear() }) {
            await model.load(project: fixture.project, clip: clip, library: fixture.library)
        }
        let current = try await readyItem(model)
        XCTAssertFalse(current === previous)
        XCTAssertFalse(model.previewsRecording)
        XCTAssertEqual(model.durationSeconds, 0.8, accuracy: 1.0 / 600)
        model.seek(to: 0.3)
        try await waitForPosition(model, global: 0.3, source: 0.5)
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .milliseconds(200))
        while clock.now < deadline {
            XCTAssertTrue(model.screenPlayer.currentItem === current)
            XCTAssertNil(model.errorMessage)
            XCTAssertFalse(model.isPlaying)
            XCTAssertEqual(model.durationSeconds, 0.8, accuracy: 1.0 / 600)
            XCTAssertEqual(model.positionSeconds, 0.3, accuracy: 0.025)
            try await Task.sleep(for: .milliseconds(10))
        }
    }

    @MainActor
    func testMissingSourceFailureRecoversOnlyAfterRestoreAndExplicitReload() async throws {
        let fixture = try await PlaybackMediaFixture.make()
        let model = makeModel()
        let held = fixture.directory.appendingPathComponent(UUID().uuidString + "-held-screen.mp4")
        var moved = false
        defer {
            model.clear()
            if moved {
                do { try FileManager.default.moveItem(at: held, to: fixture.secondScreenURL) }
                catch { XCTFail("The owned missing-source fixture could not be restored.") }
            }
            remove(fixture, model: model)
        }
        try FileManager.default.moveItem(at: fixture.secondScreenURL, to: held)
        moved = true
        try await loadRecording(model, fixture: fixture)
        XCTAssertNotNil(model.errorMessage)
        XCTAssertFalse(model.isLoading)
        XCTAssertNil(model.screenPlayer.currentItem)
        XCTAssertEqual(model.durationSeconds, 0)
        model.togglePlayback()
        XCTAssertFalse(model.isPlaying)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fixture.firstScreenURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: held.path))
        try FileManager.default.moveItem(at: held, to: fixture.secondScreenURL)
        moved = false
        XCTAssertNil(model.screenPlayer.currentItem)
        try await loadRecording(model, fixture: fixture)
        _ = try await readyItem(model)
        XCTAssertNil(model.errorMessage)
        XCTAssertEqual(model.durationSeconds, 1.4, accuracy: 1.0 / 600)
        XCTAssertFalse(model.isPlaying)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fixture.secondScreenURL.path))
    }
}
