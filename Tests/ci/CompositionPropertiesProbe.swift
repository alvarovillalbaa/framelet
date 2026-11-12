import AppKit
import AVFoundation
import CoreImage
import CoreVideo
import CryptoKit
import FrameletCore
import ImageIO
import UniformTypeIdentifiers

private final class CountingOriginalCompositor: NSObject, AVVideoCompositing, @unchecked Sendable {
    private let original = SoftwareRecordingCompositor()
    private let lock = NSLock()
    private var submitted = 0
    var requestCount: Int { lock.lock(); defer { lock.unlock() }; return submitted }
    var sourcePixelBufferAttributes: [String: any Sendable]? { original.sourcePixelBufferAttributes }
    var requiredPixelBufferAttributesForRenderContext: [String: any Sendable] { original.requiredPixelBufferAttributesForRenderContext }
    func renderContextChanged(_ context: AVVideoCompositionRenderContext) { original.renderContextChanged(context) }
    func startRequest(_ request: AVAsynchronousVideoCompositionRequest) {
        lock.lock(); submitted += 1; lock.unlock(); original.startRequest(request)
    }
    func cancelAllPendingVideoCompositionRequests() { original.cancelAllPendingVideoCompositionRequests() }
}

@MainActor
private enum PropertiesProbe {
    static func finite(_ value: Double) -> Double { value.isFinite ? value : -1 }

    static func properties(_ video: AVVideoComposition?) -> [String: Any] {
        guard let video else { return [:] }
        return ["width": finite(video.renderSize.width), "height": finite(video.renderSize.height),
            "frameDuration": finite(video.frameDuration.seconds), "frameValue": video.frameDuration.value,
            "frameTimescale": video.frameDuration.timescale, "renderScale": finite(Double(video.renderScale)),
            "sourceTiming": video.sourceTrackIDForFrameTiming, "colorPrimaries": video.colorPrimaries ?? "nil",
            "colorTransferFunction": video.colorTransferFunction ?? "nil", "colorYCbCrMatrix": video.colorYCbCrMatrix ?? "nil"]
    }

    static func instructions(_ video: AVVideoComposition?) -> [[String: Any]] {
        guard let video else { return [] }
        return video.instructions.map { instruction in
            ["type": String(describing: type(of: instruction)), "start": finite(instruction.timeRange.start.seconds),
             "duration": finite(instruction.timeRange.duration.seconds), "containsTweening": instruction.containsTweening,
             "postProcessing": instruction.enablePostProcessing, "passthroughTrackID": instruction.passthroughTrackID,
             "requiredTrackIDs": instruction.requiredSourceTrackIDs?.map { ($0 as? NSNumber)?.intValue ?? -1 } ?? []]
        }
    }

    static func run() async throws {
        guard CommandLine.arguments.count == 3 else { throw CocoaError(.fileReadInvalidFileName) }
        let package = URL(fileURLWithPath: CommandLine.arguments[1]), output = URL(fileURLWithPath: CommandLine.arguments[2])
        guard !FileManager.default.fileExists(atPath: output.path) else { throw CocoaError(.fileWriteFileExists) }
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: false)
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let project = try decoder.decode(RecordingProject.self, from: Data(contentsOf: package.appendingPathComponent("manifest.json")))
        let built = try await RecordingCompositionBuilder.build(project: project, packageURL: package)
        let tracks = try await built.asset.loadTracks(withMediaType: .video)
        guard tracks.count == 1, let track = tracks.first else { throw CocoaError(.fileReadCorruptFile) }
        let assetDuration = try await built.asset.load(.duration)
        var sourceTracks: [[String: Any]] = []
        for sourceTrack in tracks {
            let size = try await sourceTrack.load(.naturalSize)
            let rate = try await sourceTrack.load(.nominalFrameRate)
            let transform = try await sourceTrack.load(.preferredTransform)
            sourceTracks.append(["id": sourceTrack.trackID, "width": finite(size.width), "height": finite(size.height),
                "nominalFrameRate": finite(Double(rate)), "transform": [transform.a, transform.b, transform.c, transform.d, transform.tx, transform.ty].map { finite($0) }])
        }
        let generated = try await AVMutableVideoComposition.videoComposition(withPropertiesOf: built.asset)
        let custom = generated.mutableCopy() as! AVMutableVideoComposition
        custom.customVideoCompositorClass = CountingOriginalCompositor.self
        let rate = generated.mutableCopy() as! AVMutableVideoComposition
        rate.frameDuration = built.videoComposition.frameDuration
        let size = generated.mutableCopy() as! AVMutableVideoComposition
        size.renderSize = built.videoComposition.renderSize
        let instructions = generated.mutableCopy() as! AVMutableVideoComposition
        instructions.instructions = built.videoComposition.instructions
        guard let last = built.videoComposition.instructions.last as? AVVideoCompositionInstruction else { throw CocoaError(.fileReadCorruptFile) }
        let correctedLast = AVMutableVideoCompositionInstruction()
        correctedLast.timeRange = CMTimeRange(start: last.timeRange.start, end: assetDuration)
        correctedLast.layerInstructions = last.layerInstructions
        correctedLast.backgroundColor = last.backgroundColor
        correctedLast.enablePostProcessing = last.enablePostProcessing
        let corrected: [AVVideoCompositionInstructionProtocol] = Array(built.videoComposition.instructions.dropLast()) + [correctedLast]
        let coverage = generated.mutableCopy() as! AVMutableVideoComposition
        coverage.instructions = corrected
        let productCoverage = built.videoComposition.mutableCopy() as! AVMutableVideoComposition
        productCoverage.instructions = corrected
        productCoverage.customVideoCompositorClass = CountingOriginalCompositor.self
        let variants: [(String, AVVideoComposition?)] = [
            ("raw", nil), ("factory", generated), ("custom", custom), ("rate", rate),
            ("size", size), ("instructions", instructions), ("coverage", coverage), ("product-coverage", productCoverage)]
        let context = CIContext(options: [.useSoftwareRenderer: true, .cacheIntermediates: false])
        var rows: [[String: Any]] = [], frames: [[String: Any]] = []
        for (name, video) in variants {
            let item = AVPlayerItem(asset: built.asset); item.videoComposition = video; item.audioMix = built.audioMix
            item.forwardPlaybackEndTime = built.duration
            let pull = AVPlayerItemVideoOutput(pixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
            pull.suppressesPlayerRendering = false; item.add(pull)
            let player = AVPlayer(playerItem: item); player.isMuted = true; player.actionAtItemEnd = .pause
            let valid: Bool
            var validationError = ""
            do {
                valid = try await video?.isValid(for: built.asset, timeRange: CMTimeRange(start: .zero, duration: built.duration), validationDelegate: nil) ?? true
            } catch {
                valid = false; validationError = error.localizedDescription
            }
            var assetValid = true, allValid = true, assetValidationError = "", allValidationError = ""
            do { assetValid = try await video?.isValid(for: built.asset, timeRange: CMTimeRange(start: .zero, duration: assetDuration), validationDelegate: nil) ?? true }
            catch { assetValid = false; assetValidationError = error.localizedDescription }
            do { allValid = try await video?.isValid(for: built.asset, timeRange: CMTimeRange(start: .zero, duration: .positiveInfinity), validationDelegate: nil) ?? true }
            catch { allValid = false; allValidationError = error.localizedDescription }
            for (phase, target) in [("red", 3.0), ("blue", 15.0)] {
                var seekFinished = false, seekSucceeded = false, playing = false
                player.seek(to: CMTime(seconds: target, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero) { completed in
                    Task { @MainActor in seekSucceeded = completed; seekFinished = true }
                }
                let started = ProcessInfo.processInfo.systemUptime
                var sample: [String: Any] = [:]
                var rejectedDisplayTimes: [Double] = []
                while ProcessInfo.processInfo.systemUptime - started < 6 {
                    if seekFinished && seekSucceeded && !playing { player.play(); playing = true }
                    let current = player.currentTime()
                    if seekFinished && seekSucceeded && current.seconds >= target - 0.25 && current.seconds <= target + 5, pull.hasNewPixelBuffer(forItemTime: current) {
                        var display = CMTime.invalid
                        if let buffer = pull.copyPixelBuffer(forItemTime: current, itemTimeForDisplay: &display) {
                            guard display.seconds.isFinite, display.seconds >= target - 0.25, display.seconds <= target + 5 else {
                                if rejectedDisplayTimes.count < 16 { rejectedDisplayTimes.append(finite(display.seconds)) }
                                try await Task.sleep(nanoseconds: 20_000_000)
                                continue
                            }
                            let pixels = readPixels(buffer)
                            sample = ["currentSeconds": finite(current.seconds), "displayedSeconds": finite(display.seconds),
                                "medianRGB": pixels.rgb, "pixelReadStatus": pixels.status, "width": CVPixelBufferGetWidth(buffer),
                                "height": CVPixelBufferGetHeight(buffer), "pixelFormat": CVPixelBufferGetPixelFormatType(buffer),
                                "iosurfaceBacked": CVPixelBufferGetIOSurface(buffer) != nil]
                            let image = CIImage(cvPixelBuffer: buffer)
                            if let cg = context.createCGImage(image, from: image.extent) {
                                let filename = name + "-" + phase + ".png", url = output.appendingPathComponent(name + "-" + phase + ".png")
                                guard !FileManager.default.fileExists(atPath: url.path),
                                      let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else { throw CocoaError(.fileWriteUnknown) }
                                CGImageDestinationAddImage(destination, cg, nil)
                                guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
                                let bytes = try Data(contentsOf: url)
                                guard bytes.count <= 2 * 1024 * 1024 else { throw CocoaError(.fileWriteOutOfSpace) }
                                frames.append(["name": filename, "bytes": bytes.count,
                                    "sha256": SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()])
                                sample["png"] = filename
                            }
                            break
                        }
                    }
                    try await Task.sleep(nanoseconds: 20_000_000)
                }
                player.pause()
                let requests = (item.customVideoCompositor as? CountingOriginalCompositor)?.requestCount
                    ?? -1
                rows.append(["variant": name, "phase": phase, "requestedSeconds": target, "valid": valid, "validationError": validationError,
                    "validForAssetDuration": assetValid, "validForAllTimes": allValid, "assetValidationError": assetValidationError, "allValidationError": allValidationError,
                    "seekFinished": seekFinished, "seekSucceeded": seekSucceeded, "playerTime": finite(player.currentTime().seconds),
                    "playerStatus": player.status.rawValue, "itemStatus": item.status.rawValue,
                    "playerError": player.error?.localizedDescription ?? "", "itemError": item.error?.localizedDescription ?? "",
                    "compositorType": item.customVideoCompositor.map { String(describing: type(of: $0)) } ?? "nil",
                    "requests": requests, "instructions": Self.instructions(video), "frame": sample, "rejectedDisplayTimes": rejectedDisplayTimes,
                    "sourceTrackIDForFrameTiming": video?.sourceTrackIDForFrameTiming ?? 0,
                    "compositionProperties": properties(video),
                    "elapsedSeconds": ProcessInfo.processInfo.systemUptime - started])
                let progress = try JSONSerialization.data(withJSONObject: rows.last!, options: .sortedKeys)
                FileHandle.standardError.write(Data("FRAMELET_PROPERTIES_ROW=".utf8) + progress + Data([10]))
            }
            item.cancelPendingSeeks(); item.remove(pull); player.replaceCurrentItem(with: nil)
        }
        let rawRows = rows.filter { $0["variant"] as? String == "raw" }
        guard rawRows.count == 2 else { throw CocoaError(.fileReadCorruptFile) }
        for row in rawRows {
            guard let frame = row["frame"] as? [String: Any], let rgb = frame["medianRGB"] as? [Int], rgb.count == 3,
                  frame["pixelReadStatus"] as? Int == 0 else { throw CocoaError(.fileReadCorruptFile) }
            let channel = row["phase"] as? String == "red" ? 0 : 2
            guard (0..<3).filter({ $0 != channel }).allSatisfy({ rgb[channel] > rgb[$0] + 80 }) else { throw CocoaError(.fileReadCorruptFile) }
        }
        let report: [String: Any] = ["kind": "framelet-composition-properties-probe", "measured": true,
            "rows": rows, "frames": frames, "productLaunched": false, "visibleWindowCreated": false,
            "captureOrExportRequested": false, "originalsModified": false,
            "sourceTracks": sourceTracks, "assetDuration": finite(assetDuration.seconds), "projectDuration": finite(built.duration.seconds),
            "productCompositionProperties": properties(built.videoComposition),
            "renderAlgorithm": "Unchanged production delegate; one-property factory copies and explicit final-coverage candidates only"]
        print(String(data: try JSONSerialization.data(withJSONObject: report, options: .sortedKeys), encoding: .utf8)!)
        withExtendedLifetime(built) {}
    }

    static func readPixels(_ buffer: CVPixelBuffer) -> (status: Int, rgb: [Int]) {
        let status = CVPixelBufferLockBaseAddress(buffer, .readOnly)
        guard status == kCVReturnSuccess else { return (Int(status), []) }
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        let width = CVPixelBufferGetWidth(buffer), height = CVPixelBufferGetHeight(buffer)
        let stride = CVPixelBufferGetBytesPerRow(buffer)
        guard CVPixelBufferGetPixelFormatType(buffer) == kCVPixelFormatType_32BGRA,
              width >= 32, height >= 32, stride >= width * 4,
              let base = CVPixelBufferGetBaseAddress(buffer) else { return (-1, []) }
        var channels = [[Int]](repeating: [], count: 3)
        for y in (Int(Double(height) * 0.6) - 8)..<(Int(Double(height) * 0.6) + 8) {
            for x in (width / 2 - 8)..<(width / 2 + 8) {
                for channel in 0..<3 {
                    channels[channel].append(Int(base.load(fromByteOffset: y * stride + x * 4 + (2 - channel), as: UInt8.self)))
                }
            }
        }
        return (0, channels.map { $0.sorted()[128] })
    }


}

@main
private enum PropertiesProbeMain {
    @MainActor static func main() {
        let application = NSApplication.shared
        application.setActivationPolicy(.prohibited)
        Task { @MainActor in
            do { try await PropertiesProbe.run(); NSApp.terminate(nil) }
            catch { fputs("Properties probe failed: \(error)\n", stderr); exit(1) }
        }
        application.run()
    }
}
