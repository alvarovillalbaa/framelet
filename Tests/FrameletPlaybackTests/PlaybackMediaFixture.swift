import AVFoundation
import CoreVideo
import Darwin
import Foundation
import FrameletCore
@testable import Framelet

enum PlaybackFixtureError: Error {
    case ownership, writer, timeout, media, bounds, cleanup
}

@MainActor
private final class FixtureOutcome<Value> {
    var result: Result<Value, Error>?
}

/// T2 media generated only by the future approved native test run; never a device or capture source.
@MainActor
struct PlaybackMediaFixture {
    let directory: URL
    let library: RecordingLibrary
    let project: RecordingProject
    let firstScreenURL: URL
    let secondScreenURL: URL
    let cameraURL: URL
    let cameraPath: String
    private let root: URL
    private let rootIdentity: DirectoryIdentity
    private let directoryIdentity: DirectoryIdentity

    private struct DirectoryIdentity: Equatable {
        let device: dev_t
        let inode: ino_t
    }

    private init(directory: URL, library: RecordingLibrary, project: RecordingProject,
                 firstScreenURL: URL, secondScreenURL: URL, cameraURL: URL, cameraPath: String,
                 root: URL, rootIdentity: DirectoryIdentity, directoryIdentity: DirectoryIdentity) {
        self.directory = directory; self.library = library; self.project = project
        self.firstScreenURL = firstScreenURL; self.secondScreenURL = secondScreenURL
        self.cameraURL = cameraURL; self.cameraPath = cameraPath
        self.root = root; self.rootIdentity = rootIdentity; self.directoryIdentity = directoryIdentity
    }

    static func make() async throws -> PlaybackMediaFixture {
        let environment = ProcessInfo.processInfo.environment
        guard let supplied = environment["FRAMELET_PLAYBACK_ROOT"], supplied.hasPrefix("/"),
              !supplied.contains("\0"), let temporary = environment["RUNNER_TEMP"], temporary.hasPrefix("/"),
              let runID = environment["GITHUB_RUN_ID"],
              runID.range(of: "^[0-9]{1,24}$", options: .regularExpression) != nil else {
            throw PlaybackFixtureError.ownership
        }
        let root = URL(fileURLWithPath: supplied, isDirectory: true).standardizedFileURL
        let expected = URL(fileURLWithPath: temporary, isDirectory: true).resolvingSymlinksInPath()
            .appendingPathComponent("framelet-playback-" + runID, isDirectory: true)
        guard root.path == expected.path else { throw PlaybackFixtureError.ownership }
        let rootIdentity = try identity(root, permissions: 0o700)
        let directory = root.appendingPathComponent(UUID().uuidString, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false,
                                                    attributes: [.posixPermissions: 0o700])
        } catch { throw PlaybackFixtureError.ownership }
        let directoryIdentity = try identity(directory, permissions: 0o700)
        do {
            let library = RecordingLibrary(baseURL: directory.appendingPathComponent("Recordings", isDirectory: true))
            guard library.errorMessage == nil else { throw PlaybackFixtureError.media }
            var options = CaptureOptions(); options.countdownSeconds = 0
            var project = try library.create(options: options)
            let firstID = UUID(), secondID = UUID()
            let firstPath = "segments/" + firstID.uuidString + "-screen.mp4"
            let secondPath = "segments/" + secondID.uuidString + "-screen.mp4"
            let cameraPath = "segments/" + firstID.uuidString + "-camera.mov"
            let firstURL = try library.newMediaURL(projectID: project.id, path: firstPath)
            let secondURL = try library.newMediaURL(projectID: project.id, path: secondPath)
            let cameraURL = try library.newMediaURL(projectID: project.id, path: cameraPath)
            try await writeVideo(to: firstURL, fileType: .mp4, color: (220, 25, 25))
            try await writeVideo(to: secondURL, fileType: .mp4, color: (25, 40, 220))
            try await writeVideo(to: cameraURL, fileType: .mov, color: (20, 210, 40))
            let firstDuration = try await videoDuration(firstURL)
            let secondDuration = try await videoDuration(secondURL)
            _ = try await videoDuration(cameraURL)
            var bytes = 0
            for url in [firstURL, secondURL, cameraURL] {
                let values = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey, .isSymbolicLinkKey])
                guard values.isRegularFile == true, values.isSymbolicLink != true,
                      let size = values.fileSize, size > 0 else { throw PlaybackFixtureError.media }
                bytes += size
            }
            guard bytes < 4 * 1024 * 1024 else { throw PlaybackFixtureError.bounds }
            project.title = "Authored synthetic playback"
            project.status = .ready
            project.segments = [
                RecordingSegment(id: firstID, screenPath: firstPath, durationSeconds: firstDuration),
                RecordingSegment(id: secondID, screenPath: secondPath, durationSeconds: secondDuration),
            ]
            project.clips = [
                RecordingClip(segmentID: firstID, trimStartSeconds: 0.1, trimEndSeconds: 0.7),
                RecordingClip(segmentID: secondID, trimStartSeconds: 0.2, trimEndSeconds: 1.0),
            ]
            try library.save(project)
            return PlaybackMediaFixture(directory: directory, library: library, project: project,
                firstScreenURL: firstURL, secondScreenURL: secondURL, cameraURL: cameraURL, cameraPath: cameraPath,
                root: root, rootIdentity: rootIdentity, directoryIdentity: directoryIdentity)
        } catch {
            do { try removeOwned(directory, root: root, rootIdentity: rootIdentity, directoryIdentity: directoryIdentity) }
            catch { throw PlaybackFixtureError.cleanup }
            if error is CancellationError { throw CancellationError() }
            throw (error as? PlaybackFixtureError) ?? PlaybackFixtureError.media
        }
    }

    func remove() throws {
        try Self.removeOwned(directory, root: root, rootIdentity: rootIdentity, directoryIdentity: directoryIdentity)
    }

    /// A finite cooperative wait; a timed-out opaque native operation is cancelled, never awaited indefinitely.
    static func wait<Value>(timeout: Duration = .seconds(10), onTimeout: @escaping @MainActor () -> Void = {},
                            _ operation: @escaping @MainActor () async throws -> Value) async throws -> Value {
        let outcome = FixtureOutcome<Value>()
        let work = Task { @MainActor in
            do { outcome.result = .success(try await operation()) }
            catch { outcome.result = .failure(error) }
        }
        var completed = false
        defer { work.cancel(); if !completed { onTimeout() } }
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while outcome.result == nil, clock.now < deadline {
            try Task.checkCancellation()
            try await Task.sleep(for: .milliseconds(5))
        }
        try Task.checkCancellation()
        guard clock.now < deadline, let result = outcome.result else { throw PlaybackFixtureError.timeout }
        completed = true
        return try result.get()
    }

    private static func identity(_ url: URL, permissions: mode_t) throws -> DirectoryIdentity {
        var info = stat()
        guard url.path == url.resolvingSymlinksInPath().path,
              lstat(url.path, &info) == 0, info.st_mode & S_IFMT == S_IFDIR,
              info.st_mode & 0o777 == permissions else { throw PlaybackFixtureError.ownership }
        return DirectoryIdentity(device: info.st_dev, inode: info.st_ino)
    }

    private static func removeOwned(_ directory: URL, root: URL, rootIdentity: DirectoryIdentity,
                                    directoryIdentity: DirectoryIdentity) throws {
        guard directory.deletingLastPathComponent() == root,
              UUID(uuidString: directory.lastPathComponent) != nil,
              try identity(root, permissions: 0o700) == rootIdentity,
              try identity(directory, permissions: 0o700) == directoryIdentity else {
            throw PlaybackFixtureError.ownership
        }
        do { try FileManager.default.removeItem(at: directory) }
        catch { throw PlaybackFixtureError.cleanup }
    }

    private static func writeVideo(to url: URL, fileType: AVFileType, color: (UInt8, UInt8, UInt8)) async throws {
        let writer = try AVAssetWriter(outputURL: url, fileType: fileType)
        defer { if writer.status != .completed { writer.cancelWriting() } }
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: 64, AVVideoHeightKey: 48,
            AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 64_000, AVVideoMaxKeyFrameIntervalKey: 1],
        ])
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input,
            sourcePixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                                         kCVPixelBufferWidthKey as String: 64, kCVPixelBufferHeightKey as String: 48])
        guard writer.canAdd(input) else { throw PlaybackFixtureError.writer }
        writer.add(input)
        guard writer.startWriting() else { throw PlaybackFixtureError.writer }
        writer.startSession(atSourceTime: .zero)
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(10))
        for frame in 0..<12 {
            while !input.isReadyForMoreMediaData {
                try Task.checkCancellation()
                guard clock.now < deadline, writer.status == .writing else { throw PlaybackFixtureError.timeout }
                try await Task.sleep(for: .milliseconds(5))
            }
            try Task.checkCancellation()
            guard clock.now < deadline else { throw PlaybackFixtureError.timeout }
            let buffer = try pixelBuffer(color: color)
            guard adaptor.append(buffer, withPresentationTime: CMTime(value: Int64(frame), timescale: 10)) else {
                throw PlaybackFixtureError.writer
            }
        }
        input.markAsFinished()
        writer.endSession(atSourceTime: CMTime(value: 12, timescale: 10))
        writer.finishWriting { }
        while writer.status == .writing {
            try Task.checkCancellation()
            guard clock.now < deadline else { throw PlaybackFixtureError.timeout }
            try await Task.sleep(for: .milliseconds(5))
        }
        guard clock.now < deadline else { throw PlaybackFixtureError.timeout }
        guard writer.status == .completed else { throw PlaybackFixtureError.writer }
    }

    private static func pixelBuffer(color: (UInt8, UInt8, UInt8)) throws -> CVPixelBuffer {
        var buffer: CVPixelBuffer?
        guard CVPixelBufferCreate(kCFAllocatorDefault, 64, 48, kCVPixelFormatType_32BGRA,
            [kCVPixelBufferCGImageCompatibilityKey as String: true,
             kCVPixelBufferCGBitmapContextCompatibilityKey as String: true] as CFDictionary,
            &buffer) == kCVReturnSuccess, let buffer else { throw PlaybackFixtureError.writer }
        guard CVPixelBufferLockBaseAddress(buffer, []) == kCVReturnSuccess else { throw PlaybackFixtureError.writer }
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let base = CVPixelBufferGetBaseAddress(buffer) else { throw PlaybackFixtureError.writer }
        memset(base, 0, CVPixelBufferGetDataSize(buffer))
        for row in 0..<48 {
            let pixels = base.advanced(by: row * CVPixelBufferGetBytesPerRow(buffer)).assumingMemoryBound(to: UInt8.self)
            for column in 0..<64 {
                pixels[column * 4] = color.2; pixels[column * 4 + 1] = color.1
                pixels[column * 4 + 2] = color.0; pixels[column * 4 + 3] = 255
            }
        }
        return buffer
    }

    private static func videoDuration(_ url: URL) async throws -> Double {
        let asset = AVURLAsset(url: url)
        return try await wait(onTimeout: { asset.cancelLoading() }) {
            guard let track = try await asset.loadTracks(withMediaType: .video).first else { throw PlaybackFixtureError.media }
            let range = try await track.load(.timeRange)
            guard range.start.isNumeric, abs(range.start.seconds) < 0.001,
                  range.duration.isNumeric, (1.15...1.25).contains(range.duration.seconds) else {
                throw PlaybackFixtureError.media
            }
            return range.duration.seconds
        }
    }
}
