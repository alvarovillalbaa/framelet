import AVFoundation
import CoreGraphics
import Foundation
import FrameletCore

@MainActor
struct RecordingComposition {
    let asset: AVComposition
    let videoComposition: AVVideoComposition
    let audioMix: AVAudioMix?
    let duration: CMTime
    // Keep the source assets alive with the assembled preview/export snapshot.
    private let sourceAssets: [AVURLAsset]

    fileprivate init(asset: AVComposition, videoComposition: AVVideoComposition,
                     audioMix: AVAudioMix?, duration: CMTime, sourceAssets: [AVURLAsset]) {
        self.asset = asset
        self.videoComposition = videoComposition
        self.audioMix = audioMix
        self.duration = duration
        self.sourceAssets = sourceAssets
    }
}

@MainActor
enum RecordingCompositionBuilder {
    static func build(project: RecordingProject, packageURL: URL,
                      onProgress: (Double) -> Void = { _ in }) async throws -> RecordingComposition {
        guard project.status != .recording, project.status != .paused else { throw ExportFailure.activeRecording }
        let slices = try recordingTimeline(project)
        let duration = seconds(project.durationSeconds)
        guard project.durationSeconds.isFinite, duration.isNumeric, CMTimeCompare(duration, .zero) > 0,
              slices.allSatisfy({ $0.timelineStartSeconds.isFinite }) else { throw RecordingValidationError.invalidTiming }
        let package = try ExportPaths.directory(packageURL)
        guard package.pathExtension == "framelet" else { throw RecordingValidationError.unsafePath }
        try Task.checkCancellation()
        onProgress(0)

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
                try Task.checkCancellation()
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
            try Task.checkCancellation()
            onProgress(Double(index + 1) / Double(slices.count))
            await Task.yield()
            try Task.checkCancellation()
        }
        let video = AVMutableVideoComposition()
        video.renderSize = canvas
        video.frameDuration = CMTime(value: 1, timescale: 30)
        video.instructions = instructions
        // An unused camera track is unnecessary and can prevent preset compatibility.
        if cameraTrack.segments.isEmpty { composition.removeTrack(cameraTrack) }
        // Explicit unity gains include all independent source tracks in the export mix.
        let mix = AVMutableAudioMix()
        mix.inputParameters = audioTracks.values.map { track in
            let parameters = AVMutableAudioMixInputParameters(track: track)
            parameters.setVolume(1, at: .zero)
            return parameters
        }
        let sourceAssets = loaded.values.flatMap { media in
            [media.screen.asset] + (media.camera.map { [$0.asset] } ?? [])
        }
        try Task.checkCancellation()
        return RecordingComposition(asset: composition, videoComposition: video,
            audioMix: mix.inputParameters.isEmpty ? nil : mix, duration: duration, sourceAssets: sourceAssets)
    }

    private static func layer(_ track: AVCompositionTrack, placement: ExportGeometry.Placement,
                              at time: CMTime) -> AVMutableVideoCompositionLayerInstruction {
        let result = AVMutableVideoCompositionLayerInstruction(assetTrack: track)
        result.setCropRectangle(placement.sourceCrop, at: time)
        result.setTransform(placement.transform, at: time)
        return result
    }

    private static func loadSegment(_ segment: RecordingSegment, package: URL) async throws -> SegmentMedia {
        let screen = try await loadMedia(ExportPaths.media(segment.screenPath, package: package))
        let camera: MediaTrack?
        if let path = segment.cameraPath { camera = try await loadMedia(ExportPaths.media(path, package: package)) }
        else { camera = nil }
        return SegmentMedia(screen: screen, camera: camera)
    }

    private static func loadMedia(_ url: URL) async throws -> MediaTrack {
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

    private static func insertAudio(_ audio: [AudioTrack], requested: CMTimeRange, at target: CMTime,
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
    let asset: AVURLAsset
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
