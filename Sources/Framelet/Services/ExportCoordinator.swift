import AVFoundation
import CoreGraphics
import Darwin
import Foundation
import FrameletCore
import Observation

@MainActor @Observable
final class ExportCoordinator {
    private(set) var isExporting = false
    private(set) var progress = 0.0
    private(set) var errorMessage: String?
    private(set) var outputURL: URL?
    @ObservationIgnored private var operation: Task<URL, Error>?

    func export(project: RecordingProject, packageURL: URL, destinationURL: URL) async {
        guard !isExporting else { return }
        isExporting = true
        progress = 0
        errorMessage = nil
        outputURL = nil
        let task = Task { @MainActor in
            try await self.performExport(project: project, packageURL: packageURL, destinationURL: destinationURL)
        }
        operation = task
        defer { operation = nil; isExporting = false }
        do {
            outputURL = try await withTaskCancellationHandler {
                try await task.value
            } onCancel: {
                task.cancel()
            }
            progress = 1
        } catch is CancellationError {
            progress = 0
            errorMessage = "Export cancelled. Your source recordings have been retained."
        } catch {
            progress = 0
            errorMessage = error.localizedDescription
        }
    }

    func cancel() { operation?.cancel() }

    private func performExport(project: RecordingProject, packageURL: URL, destinationURL: URL) async throws -> URL {
        guard project.status != .recording, project.status != .paused else { throw ExportFailure.activeRecording }
        let slices = try recordingTimeline(project)
        let duration = seconds(project.durationSeconds)
        guard project.durationSeconds.isFinite, duration.isNumeric, CMTimeCompare(duration, .zero) > 0,
              slices.allSatisfy({ $0.timelineStartSeconds.isFinite }) else { throw RecordingValidationError.invalidTiming }
        let package = try ExportPaths.directory(packageURL)
        guard package.pathExtension == "framelet" else { throw RecordingValidationError.unsafePath }
        let destination = destinationURL.standardizedFileURL
        guard destination.isFileURL, destination.pathExtension.lowercased() == "mp4",
              !ExportPaths.contains(destination, in: package) else { throw ExportFailure.unsafeDestination }
        try Task.checkCancellation()
        let staging = try ExportStaging(destination: destination)
        defer { staging.cleanUp() }

        let composition = AVMutableComposition()
        guard let screenTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
              let cameraTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw ExportFailure.composition
        }
        let canvas = CGSize(width: CGFloat(project.presentation.preset.width), height: CGFloat(project.presentation.preset.height))
        let color = project.presentation.background.rgb
        let background = CGColor(red: CGFloat(color.0), green: CGFloat(color.1), blue: CGFloat(color.2), alpha: 1)
        var instructions: [AVVideoCompositionInstructionProtocol] = []
        var loaded: [UUID: SegmentMedia] = [:]
        var audioTracks: [Int: AVMutableCompositionTrack] = [:]

        for (index, slice) in slices.enumerated() {
            try Task.checkCancellation()
            let media: SegmentMedia
            if let cached = loaded[slice.segment.id] { media = cached }
            else {
                media = try await loadSegment(slice.segment, package: package)
                loaded[slice.segment.id] = media
            }
            let clipRange = try media.screen.clipRange(start: slice.sourceStartSeconds, duration: slice.durationSeconds)
            let start = seconds(slice.timelineStartSeconds)
            let end = seconds(slice.timelineStartSeconds + slice.durationSeconds)
            try screenTrack.insertTimeRange(clipRange, of: media.screen.video, at: start)
            try insertAudio(media.screen.audio, requested: clipRange, at: start,
                            composition: composition, tracks: &audioTracks, slotOffset: 0)
            let screenPlacement = try ExportGeometry.placement(size: media.screen.size,
                preferredTransform: media.screen.transform, rect: project.presentation.screenRect,
                canvas: canvas, fill: false)

            var cameraWindow: CMTimeRange?
            var cameraPlacement: ExportGeometry.Placement?
            if let camera = media.camera {
                if let overlap = try cameraOverlap(slice: slice, cameraDurationSeconds: camera.range.duration.seconds) {
                    let available = try camera.clipRange(start: overlap.sourceStartSeconds, duration: overlap.durationSeconds)
                    let target = seconds(overlap.timelineStartSeconds)
                    let sourceRange = CMTimeRange(start: available.start,
                        duration: CMTimeMinimum(available.duration, CMTimeSubtract(end, target)))
                    // Camera audio is normally absent; preserve every track if a sidecar has it.
                    try insertAudio(camera.audio, requested: sourceRange, at: target,
                                    composition: composition, tracks: &audioTracks, slotOffset: media.screen.audio.count)
                    if let rect = project.presentation.cameraRect {
                        try cameraTrack.insertTimeRange(sourceRange, of: camera.video, at: target)
                        cameraWindow = CMTimeRange(start: target, duration: sourceRange.duration)
                        cameraPlacement = try ExportGeometry.placement(size: camera.size,
                            preferredTransform: camera.transform, rect: rect, canvas: canvas,
                            fill: true, mirrored: project.presentation.cameraMirrored)
                    }
                }
            }
            // Separate instructions around camera gaps avoid requesting absent frames
            // or holding a previous camera image over a late/short sidecar.
            var cuts = [start, end]
            if let window = cameraWindow {
                cuts.append(window.start)
                cuts.append(CMTimeRangeGetEnd(window))
            }
            cuts.sort { CMTimeCompare($0, $1) < 0 }
            for pair in zip(cuts, cuts.dropFirst()) where CMTimeCompare(pair.1, pair.0) > 0 {
                let instruction = AVMutableVideoCompositionInstruction()
                instruction.timeRange = CMTimeRange(start: pair.0, end: pair.1)
                instruction.backgroundColor = background
                let screen = layer(screenTrack, placement: screenPlacement, at: pair.0)
                if let window = cameraWindow, let placement = cameraPlacement,
                   CMTimeCompare(pair.0, window.start) >= 0, CMTimeCompare(pair.1, CMTimeRangeGetEnd(window)) <= 0 {
                    instruction.layerInstructions = [layer(cameraTrack, placement: placement, at: pair.0), screen]
                } else { instruction.layerInstructions = [screen] }
                instructions.append(instruction)
            }
            progress = 0.1 * Double(index + 1) / Double(slices.count)
            await Task.yield()
        }
        let video = AVMutableVideoComposition()
        video.renderSize = canvas
        video.frameDuration = CMTime(value: 1, timescale: 30)
        video.instructions = instructions
        // An unused camera track is unnecessary and can prevent preset compatibility.
        if cameraTrack.segments.isEmpty { composition.removeTrack(cameraTrack) }
        guard let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality),
              exporter.supportedFileTypes.contains(.mp4) else { throw ExportFailure.unsupportedExport }
        exporter.videoComposition = video
        exporter.timeRange = CMTimeRange(start: .zero, duration: duration)
        exporter.shouldOptimizeForNetworkUse = false
        // Explicit unity gains include all independent source tracks in the export mix.
        let mix = AVMutableAudioMix()
        mix.inputParameters = audioTracks.values.map { track in
            let parameters = AVMutableAudioMixInputParameters(track: track)
            parameters.setVolume(1, at: .zero)
            return parameters
        }
        if !mix.inputParameters.isEmpty { exporter.audioMix = mix }
        try staging.validateIdentity()
        let monitor = Task { @MainActor [weak self] in
            for await state in exporter.states(updateInterval: 0.2) {
                if Task.isCancelled { break }
                if case .exporting(let value) = state {
                    self?.progress = 0.1 + 0.89 * min(1, max(0, value.fractionCompleted))
                }
            }
        }
        defer { monitor.cancel() }
        try Task.checkCancellation()
        try await exporter.export(to: staging.output, as: .mp4)
        try Task.checkCancellation()
        try staging.commit()
        return destination
    }

    private func layer(_ track: AVCompositionTrack, placement: ExportGeometry.Placement,
                       at time: CMTime) -> AVMutableVideoCompositionLayerInstruction {
        let result = AVMutableVideoCompositionLayerInstruction(assetTrack: track)
        result.setCropRectangle(placement.sourceCrop, at: time)
        result.setTransform(placement.transform, at: time)
        return result
    }

    private func loadSegment(_ segment: RecordingSegment, package: URL) async throws -> SegmentMedia {
        let screen = try await loadMedia(ExportPaths.media(segment.screenPath, package: package))
        let camera: MediaTrack?
        if let path = segment.cameraPath { camera = try await loadMedia(ExportPaths.media(path, package: package)) }
        else { camera = nil }
        return SegmentMedia(screen: screen, camera: camera)
    }

    private func loadMedia(_ url: URL) async throws -> MediaTrack {
        try Task.checkCancellation()
        let asset = AVURLAsset(url: url, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
        let videos = try await asset.loadTracks(withMediaType: .video)
        guard videos.count == 1, let track = videos.first else { throw ExportFailure.invalidMedia }
        let range = try await track.load(.timeRange)
        guard range.start.isNumeric, range.duration.isNumeric,
              range.duration.seconds.isFinite, range.duration.seconds > 0 else { throw ExportFailure.invalidMedia }
        let size = try await track.load(.naturalSize)
        let transform = try await track.load(.preferredTransform)
        let audio = try await asset.loadTracks(withMediaType: .audio)
        var sound: [AudioTrack] = []
        for track in audio {
            try Task.checkCancellation()
            let interval = try await track.load(.timeRange)
            guard interval.start.isNumeric, interval.duration.isNumeric,
                  interval.duration.seconds.isFinite, interval.duration.seconds >= 0 else { throw ExportFailure.invalidMedia }
            sound.append(AudioTrack(track: track, range: interval))
        }
        return MediaTrack(asset: asset, video: track, range: range, size: size, transform: transform, audio: sound)
    }

    private func insertAudio(_ audio: [AudioTrack], requested: CMTimeRange, at target: CMTime,
                             composition: AVMutableComposition,
                             tracks: inout [Int: AVMutableCompositionTrack], slotOffset: Int) throws {
        for (index, source) in audio.enumerated() {
            let overlap = source.range.intersection(requested)
            guard overlap.isValid, !overlap.isEmpty, overlap.duration.isNumeric,
                  CMTimeCompare(overlap.duration, .zero) > 0 else { continue }
            let key = slotOffset + index
            let destination: AVMutableCompositionTrack
            if let existing = tracks[key] { destination = existing }
            else {
                guard let new = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
                    throw ExportFailure.composition
                }
                destination = new; tracks[key] = new
            }
            try destination.insertTimeRange(overlap, of: source.track,
                at: CMTimeAdd(target, CMTimeSubtract(overlap.start, requested.start)))
        }
    }
}

private let exportTimescale: CMTimeScale = 600_000
private func seconds(_ value: Double) -> CMTime { CMTime(seconds: value, preferredTimescale: exportTimescale) }

private struct AudioTrack { let track: AVAssetTrack; let range: CMTimeRange }
private struct SegmentMedia { let screen: MediaTrack; let camera: MediaTrack? }
private struct MediaTrack {
    let asset: AVURLAsset // Retain the source asset throughout export.
    let video: AVAssetTrack
    let range: CMTimeRange
    let size: CGSize
    let transform: CGAffineTransform
    let audio: [AudioTrack]

    func clipRange(start: Double, duration: Double) throws -> CMTimeRange {
        guard start.isFinite, duration.isFinite, start >= 0, duration > 0,
              start + duration <= range.duration.seconds + 1 / Double(exportTimescale) else {
            throw ExportFailure.invalidTrim
        }
        let begin = CMTimeAdd(range.start, seconds(start))
        let end = CMTimeMinimum(CMTimeAdd(range.start, seconds(start + duration)), CMTimeRangeGetEnd(range))
        guard CMTimeCompare(end, begin) > 0 else { throw ExportFailure.invalidTrim }
        return CMTimeRange(start: begin, end: end)
    }
}

enum ExportFailure: LocalizedError {
    case activeRecording, invalidMedia, invalidTrim, unsupportedOrientation, composition
    case unsafeDestination, destinationExists, unsupportedExport, changedPath
    var errorDescription: String? {
        switch self {
        case .activeRecording: "Stop recording before exporting this project."
        case .invalidMedia: "A recording file is missing a readable video or has invalid media timing. Originals have been retained."
        case .invalidTrim: "A clip extends beyond its actual media. Adjust its trim before exporting."
        case .unsupportedOrientation: "A source has an unsupported video orientation. Its original file has been retained."
        case .composition: "The recording tracks could not be assembled for export."
        case .unsafeDestination: "Choose a new MP4 outside the recording package in a folder without symbolic links."
        case .destinationExists: "A file already exists at this destination. Choose a new export name."
        case .unsupportedExport: "This recording cannot be exported as MP4 with the available media encoder."
        case .changedPath: "An export folder or source path changed. Choose the destination again."
        }
    }
}

private enum ExportPaths {
    static func contains(_ child: URL, in parent: URL) -> Bool {
        child.path == parent.path || child.path.hasPrefix(parent.path + "/")
    }

    static func directory(_ url: URL) throws -> URL {
        guard url.isFileURL else { throw RecordingValidationError.unsafePath }
        let clean = url.standardizedFileURL
        guard clean.path == clean.resolvingSymlinksInPath().path else { throw RecordingValidationError.unsafePath }
        let values = try clean.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard values.isDirectory == true, values.isSymbolicLink != true else { throw RecordingValidationError.unsafePath }
        return clean
    }

    static func media(_ path: String, package: URL) throws -> URL {
        guard isSafeRecordingPath(path) else { throw RecordingValidationError.unsafePath }
        let url = package.appendingPathComponent(path).standardizedFileURL
        guard contains(url, in: package), url.path == url.resolvingSymlinksInPath().path else {
            throw RecordingValidationError.unsafePath
        }
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .isReadableKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true,
              values.isReadable == true else { throw ExportFailure.invalidMedia }
        return url
    }
}

/// Private staging directory on the destination volume; the final rename is
/// atomic and exclusive even if another process creates the destination meanwhile.
private final class ExportStaging {
    private let parent: URL
    private let parentFD: Int32
    private let directoryFD: Int32
    private let directoryName: String
    private let destinationName: String
    private let directory: URL
    let output: URL

    init(destination: URL) throws {
        parent = try ExportPaths.directory(destination.deletingLastPathComponent())
        destinationName = destination.lastPathComponent
        directoryName = ".framelet-export-" + UUID().uuidString
        directory = parent.appendingPathComponent(directoryName, isDirectory: true)
        output = directory.appendingPathComponent("output.mp4")
        let parentDescriptor = open(parent.path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW)
        guard parentDescriptor >= 0 else { throw Self.posixError() }
        var existing = stat()
        if fstatat(parentDescriptor, destinationName, &existing, AT_SYMLINK_NOFOLLOW) == 0 {
            close(parentDescriptor); throw ExportFailure.destinationExists
        }
        guard errno == ENOENT else { let error = Self.posixError(); close(parentDescriptor); throw error }
        guard mkdirat(parentDescriptor, directoryName, 0o700) == 0 else {
            let error = Self.posixError(); close(parentDescriptor); throw error
        }
        let descriptor = openat(parentDescriptor, directoryName, O_RDONLY | O_DIRECTORY | O_NOFOLLOW)
        guard descriptor >= 0 else {
            let error = Self.posixError()
            unlinkat(parentDescriptor, directoryName, AT_REMOVEDIR); close(parentDescriptor)
            throw error
        }
        parentFD = parentDescriptor
        directoryFD = descriptor
    }

    deinit { close(directoryFD); close(parentFD) }

    func validateIdentity() throws {
        _ = try ExportPaths.directory(parent)
        _ = try ExportPaths.directory(directory)
        var parentInfo = stat(); var pathInfo = stat()
        guard fstat(parentFD, &parentInfo) == 0, lstat(parent.path, &pathInfo) == 0,
              parentInfo.st_dev == pathInfo.st_dev, parentInfo.st_ino == pathInfo.st_ino,
              fstat(directoryFD, &parentInfo) == 0, lstat(directory.path, &pathInfo) == 0,
              parentInfo.st_dev == pathInfo.st_dev, parentInfo.st_ino == pathInfo.st_ino else { throw ExportFailure.changedPath }
    }

    func commit() throws {
        try validateIdentity()
        var info = stat()
        guard fstatat(directoryFD, "output.mp4", &info, AT_SYMLINK_NOFOLLOW) == 0,
              (info.st_mode & S_IFMT) == S_IFREG, info.st_size > 0 else { throw ExportFailure.invalidMedia }
        if renameatx_np(directoryFD, "output.mp4", parentFD, destinationName, UInt32(RENAME_EXCL)) != 0 {
            if errno == EEXIST { throw ExportFailure.destinationExists }
            throw Self.posixError()
        }
    }

    func cleanUp() {
        // Never recursively remove a folder or touch the final destination.
        unlinkat(directoryFD, "output.mp4", 0)
        unlinkat(parentFD, directoryName, AT_REMOVEDIR)
    }

    private static func posixError() -> NSError {
        NSError(domain: NSPOSIXErrorDomain, code: Int(errno), userInfo: [NSLocalizedDescriptionKey:
            "The export file could not be written (\(String(cString: strerror(errno)))). Your source recordings have been retained."])
    }
}
