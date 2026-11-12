import AppKit
import AVFoundation
import CoreImage
import CoreVideo
import CryptoKit
import FrameletCore
import ImageIO
import UniformTypeIdentifiers

@MainActor
private enum ExactCoverageProbe {
    static func need(_ value: Bool, _ reason: String) throws {
        if !value { throw NSError(domain: "FrameletExactCoverage", code: 1, userInfo: [NSLocalizedDescriptionKey: reason]) }
    }

    static func run() async throws {
        try need(CommandLine.arguments.count == 3, "expected authored package and new output")
        let package = URL(fileURLWithPath: CommandLine.arguments[1]), output = URL(fileURLWithPath: CommandLine.arguments[2])
        try need(!FileManager.default.fileExists(atPath: output.path), "output exists")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: false)
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let original = try decoder.decode(RecordingProject.self, from: Data(contentsOf: package.appendingPathComponent("manifest.json")))
        try need(original.status == .ready && original.clips.count == 2, "authored project shape")
        var trimmed = original
        trimmed.clips[0].trimStartSeconds += 0.011113
        trimmed.clips[1].trimEndSeconds -= 0.123457
        var reordered = original; reordered.clips.reverse()
        let cases: [(String, RecordingProject, [String])] = [
            ("original", original, ["red", "blue"]), ("trimmed", trimmed, ["red", "blue"]),
            ("reordered", reordered, ["blue", "red"])]
        let context = CIContext(options: [.useSoftwareRenderer: true, .cacheIntermediates: false])
        var rows: [[String: Any]] = [], frames: [[String: Any]] = [], caseRows: [[String: Any]] = []
        for (name, project, colors) in cases {
            let built = try await RecordingCompositionBuilder.build(project: project, packageURL: package)
            let assetDuration = try await built.asset.load(.duration)
            guard let last = built.videoComposition.instructions.last else { throw CocoaError(.fileReadCorruptFile) }
            try need(CMTimeCompare(CMTimeRangeGetEnd(last.timeRange), assetDuration) == 0, "final instruction must equal actual asset duration: " + name)
            let video = try SoftwareRecordingCompositor.videoComposition(from: built.videoComposition)
            let valid = try await video.isValid(for: built.asset, timeRange: CMTimeRange(start: .zero, duration: assetDuration), validationDelegate: nil)
            let validAll = try await video.isValid(for: built.asset, timeRange: CMTimeRange(start: .zero, duration: .positiveInfinity), validationDelegate: nil)
            try need(valid && validAll, "full-asset/all-time validity: " + name)
            caseRows.append(["name": name, "assetDuration": assetDuration.seconds, "projectDuration": built.duration.seconds,
                "instructionEnd": CMTimeRangeGetEnd(last.timeRange).seconds, "validForAsset": valid, "validForAllTimes": validAll])
            let item = AVPlayerItem(asset: built.asset); item.videoComposition = video; item.audioMix = built.audioMix
            item.forwardPlaybackEndTime = built.duration
            let pull = AVPlayerItemVideoOutput(pixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
            pull.suppressesPlayerRendering = false; item.add(pull)
            let player = AVPlayer(playerItem: item); player.isMuted = true; player.actionAtItemEnd = .pause
            for (index, target) in [3.0, 15.0].enumerated() {
                let phase = index == 0 ? "first" : "second", expected = colors[index]
                var seekFinished = false, seekSucceeded = false, playing = false
                player.seek(to: CMTime(seconds: target, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero) { completed in
                    Task { @MainActor in seekSucceeded = completed; seekFinished = true }
                }
                let started = ProcessInfo.processInfo.systemUptime
                var sample: [String: Any] = [:], rejected: [Double] = []
                while ProcessInfo.processInfo.systemUptime - started < 6 {
                    if seekFinished && seekSucceeded && !playing { player.play(); playing = true }
                    let current = player.currentTime()
                    if seekFinished && seekSucceeded && current.seconds >= target - 0.25 && current.seconds <= target + 5,
                       pull.hasNewPixelBuffer(forItemTime: current) {
                        var display = CMTime.invalid
                        if let buffer = pull.copyPixelBuffer(forItemTime: current, itemTimeForDisplay: &display) {
                            guard display.seconds.isFinite, display.seconds >= target - 0.25, display.seconds <= target + 5 else {
                                if rejected.count < 16 { rejected.append(display.seconds.isFinite ? display.seconds : -1) }
                                try await Task.sleep(nanoseconds: 20_000_000); continue
                            }
                            let center = pixels(buffer, x: 0.5, y: 0.6), header = pixels(buffer, x: 0.5, y: 0.11), matte = pixels(buffer, x: 0.01, y: 0.01)
                            sample = ["currentSeconds": current.seconds, "displayedSeconds": display.seconds,
                                "medianRGB": center, "headerRGB": header, "matteRGB": matte,
                                "width": CVPixelBufferGetWidth(buffer), "height": CVPixelBufferGetHeight(buffer)]
                            let image = CIImage(cvPixelBuffer: buffer)
                            guard let cg = context.createCGImage(image, from: image.extent) else { throw CocoaError(.fileReadCorruptFile) }
                            let filename = name + "-" + phase + ".png", url = output.appendingPathComponent(name + "-" + phase + ".png")
                            guard !FileManager.default.fileExists(atPath: url.path),
                                  let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else { throw CocoaError(.fileWriteUnknown) }
                            CGImageDestinationAddImage(destination, cg, nil)
                            try need(CGImageDestinationFinalize(destination), "PNG finalization")
                            let bytes = try Data(contentsOf: url); try need(bytes.count <= 2 * 1024 * 1024, "PNG bound")
                            frames.append(["name": filename, "bytes": bytes.count, "sha256": SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()])
                            sample["png"] = filename
                            break
                        }
                    }
                    try await Task.sleep(nanoseconds: 20_000_000)
                }
                player.pause()
                let actualClass = item.customVideoCompositor is SoftwareRecordingCompositor
                let row: [String: Any] = ["case": name, "phase": phase, "expectedColor": expected, "requestedSeconds": target,
                    "seekFinished": seekFinished, "seekSucceeded": seekSucceeded, "actualProductionCompositor": actualClass,
                    "playerStatus": player.status.rawValue, "itemStatus": item.status.rawValue,
                    "playerError": player.error?.localizedDescription ?? "", "itemError": item.error?.localizedDescription ?? "",
                    "frame": sample, "rejectedDisplayTimes": rejected]
                rows.append(row)
                let progress = try JSONSerialization.data(withJSONObject: row, options: .sortedKeys)
                FileHandle.standardError.write(Data("FRAMELET_EXACT_COVERAGE_ROW=".utf8) + progress + Data([10]))
                guard let rgb = sample["medianRGB"] as? [Int], let header = sample["headerRGB"] as? [Int],
                      let matte = sample["matteRGB"] as? [Int], rgb.count == 3 && header.count == 3 && matte.count == 3 else {
                    throw NSError(domain: "FrameletExactCoverage", code: 2, userInfo: [NSLocalizedDescriptionKey: "Missing actual product pixels: " + name + "-" + phase])
                }
                let channel = expected == "red" ? 0 : 2, background = project.presentation.background.rgb
                let expectedMatte = [background.0, background.1, background.2].map { Int(($0 * 255).rounded()) }
                try need((0..<3).allSatisfy { $0 == channel || rgb[channel] > rgb[$0] + 80 }, "actual timeline color: " + name)
                try need(header.allSatisfy { $0 > 170 } && zip(matte, expectedMatte).allSatisfy { abs($0 - $1) <= 18 }, "upright header/matte: " + name)
                try need(sample["width"] as? Int == project.presentation.preset.width && sample["height"] as? Int == project.presentation.preset.height, "canvas dimensions")
                try need(actualClass && seekFinished && seekSucceeded && player.status == .readyToPlay && item.status == .readyToPlay && player.error == nil && item.error == nil, "actual production playback state")
            }
            item.cancelPendingSeeks(); item.remove(pull); player.replaceCurrentItem(with: nil)
            withExtendedLifetime(built) {}
        }
        let report: [String: Any] = ["kind": "framelet-exact-coverage-playback", "verified": true, "cases": caseRows,
            "caseCount": 3, "rows": rows, "frames": frames, "productLaunched": false, "visibleWindowCreated": false,
            "captureOrExportRequested": false, "originalsModified": false]
        print(String(data: try JSONSerialization.data(withJSONObject: report, options: .sortedKeys), encoding: .utf8)!)
    }

    static func pixels(_ buffer: CVPixelBuffer, x: Double, y: Double) -> [Int] {
        guard CVPixelBufferLockBaseAddress(buffer, .readOnly) == kCVReturnSuccess else { return [] }
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        let width = CVPixelBufferGetWidth(buffer), height = CVPixelBufferGetHeight(buffer), stride = CVPixelBufferGetBytesPerRow(buffer)
        let px = Int(Double(width) * x), py = Int(Double(height) * y)
        guard CVPixelBufferGetPixelFormatType(buffer) == kCVPixelFormatType_32BGRA,
              px >= 8, py >= 8, px + 8 <= width, py + 8 <= height, stride >= width * 4,
              let base = CVPixelBufferGetBaseAddress(buffer) else { return [] }
        var channels = [[Int]](repeating: [], count: 3)
        for row in (py - 8)..<(py + 8) {
            for column in (px - 8)..<(px + 8) {
                for channel in 0..<3 { channels[channel].append(Int(base.load(fromByteOffset: row * stride + column * 4 + (2 - channel), as: UInt8.self))) }
            }
        }
        return channels.map { $0.sorted()[128] }
    }
}

@main
private enum ExactCoverageMain {
    @MainActor static func main() {
        let application = NSApplication.shared; application.setActivationPolicy(.prohibited)
        Task { @MainActor in
            do { try await ExactCoverageProbe.run(); NSApp.terminate(nil) }
            catch { fputs("Exact coverage failed: \(error)\n", stderr); exit(1) }
        }
        application.run()
    }
}
