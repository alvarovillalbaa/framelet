import AppKit
import AVFoundation
import CoreImage
import CoreVideo
import CryptoKit
import FrameletCore
import ImageIO
import UniformTypeIdentifiers

// Only this diagnostic uses these instructions; original product inputs stay exact.
private final class ExplicitProbeInstruction: NSObject, AVVideoCompositionInstructionProtocol, @unchecked Sendable {
    let original: AVVideoCompositionInstruction
    init(_ original: AVVideoCompositionInstruction) { self.original = original; super.init() }
    var timeRange: CMTimeRange { original.timeRange }
    var enablePostProcessing: Bool { original.enablePostProcessing }
    var containsTweening: Bool { original.containsTweening }
    var passthroughTrackID: CMPersistentTrackID { kCMPersistentTrackID_Invalid }
    var requiredSourceTrackIDs: [NSValue]? {
        Array(Set(original.layerInstructions.map(\.trackID))).sorted().map { NSNumber(value: $0) }
    }
}

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

// Preview uses the export builder's static layer instructions. A software
// context also works where the system playback compositor produces no pixels.
// Mutable state is locked; rendering and request completion use one queue.
private final class ProtocolExperimentCompositor: NSObject, AVVideoCompositing, @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.alvarovillalbaa.Framelet.preview-composition")
    private let queueKey = DispatchSpecificKey<UInt8>()
    private let lock = NSLock()
    private var generation = 0
    private var submitted = 0
    var requestCount: Int { lock.lock(); defer { lock.unlock() }; return submitted }
    private let context = CIContext(options: [.useSoftwareRenderer: true, .cacheIntermediates: false])
    private let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!

    override init() {
        super.init()
        queue.setSpecific(key: queueKey, value: 1)
    }

    static func videoComposition(from original: AVVideoComposition) throws -> AVVideoComposition {
        guard let result = original.mutableCopy() as? AVMutableVideoComposition else { throw failure() }
        result.customVideoCompositorClass = ProtocolExperimentCompositor.self
        result.instructions = try original.instructions.map { value in
            guard let instruction = value as? AVVideoCompositionInstruction else { throw failure() }
            return ExplicitProbeInstruction(instruction)
        }
        return result
    }

    var sourcePixelBufferAttributes: [String: any Sendable]? {
        [kCVPixelBufferPixelFormatTypeKey as String: [kCVPixelFormatType_32BGRA]]
    }

    var requiredPixelBufferAttributesForRenderContext: [String: any Sendable] {
        [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
    }

    func renderContextChanged(_ newRenderContext: AVVideoCompositionRenderContext) {
        lock.lock(); generation += 1; lock.unlock()
    }

    func startRequest(_ request: AVAsynchronousVideoCompositionRequest) {
        lock.lock(); let token = generation; submitted += 1; lock.unlock()
        queue.async { [self] in
            guard current(token) else { request.finishCancelledRequest(); return }
            do {
                let buffer = try render(request)
                if current(token) { request.finish(withComposedVideoFrame: buffer) }
                else { request.finishCancelledRequest() }
            } catch {
                if current(token) { request.finish(with: error) }
                else { request.finishCancelledRequest() }
            }
        }
    }

    func cancelAllPendingVideoCompositionRequests() {
        lock.lock(); generation += 1; lock.unlock()
        // AVFoundation requires pending requests to finish before returning.
        // A reentrant call from a finishing callback must not sync onto itself.
        if DispatchQueue.getSpecific(key: queueKey) == nil { queue.sync {} }
    }

    private func current(_ token: Int) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return generation == token
    }

    private func render(_ request: AVAsynchronousVideoCompositionRequest) throws -> CVPixelBuffer {
        guard let instruction = (request.videoCompositionInstruction as? ExplicitProbeInstruction)?.original,
              let buffer = request.renderContext.newPixelBuffer() else { throw Self.failure() }
        let size = request.renderContext.videoComposition.renderSize
        let canvasBounds = CGRect(origin: .zero, size: size)
        guard size.width.isFinite, size.height.isFinite, size.width > 0, size.height > 0 else { throw Self.failure() }
        let background = instruction.backgroundColor ?? CGColor(gray: 0, alpha: 1)
        var canvas = CIImage(color: CIColor(cgColor: background)).cropped(to: canvasBounds)
        for layer in instruction.layerInstructions.reversed() {
            guard let source = request.sourceFrame(byTrackID: layer.trackID) else { throw Self.failure() }
            let width = CGFloat(CVPixelBufferGetWidth(source)), height = CGFloat(CVPixelBufferGetHeight(source))
            var transform = CGAffineTransform.identity, transformEnd = CGAffineTransform.identity
            var timeRange = CMTimeRange.invalid
            if layer.getTransformRamp(for: request.compositionTime, start: &transform, end: &transformEnd, timeRange: &timeRange) {
                guard transform == transformEnd else { throw Self.failure() }
            }
            var crop = CGRect(x: 0, y: 0, width: width, height: height), cropEnd = CGRect.zero
            if layer.getCropRectangleRamp(for: request.compositionTime, startCropRectangle: &crop, endCropRectangle: &cropEnd, timeRange: &timeRange) {
                guard crop == cropEnd else { throw Self.failure() }
            }
            var opacity: Float = 1, opacityEnd: Float = 1
            if layer.getOpacityRamp(for: request.compositionTime, startOpacity: &opacity, endOpacity: &opacityEnd, timeRange: &timeRange) {
                guard opacity == 1, opacityEnd == 1 else { throw Self.failure() }
            }
            guard !crop.isNull, !crop.isEmpty,
                  [crop.minX, crop.minY, crop.width, crop.height, transform.a, transform.b,
                   transform.c, transform.d, transform.tx, transform.ty].allSatisfy(\.isFinite) else { throw Self.failure() }
            // CI is bottom-left; the shared crop/transform contract is top-left.
            let sourceFlip = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: height)
            let image = CIImage(cvPixelBuffer: source)
                .transformed(by: sourceFlip).cropped(to: crop).transformed(by: transform)
            canvas = image.composited(over: canvas).cropped(to: canvasBounds)
        }
        let outputBounds = CGRect(x: 0, y: 0, width: CGFloat(CVPixelBufferGetWidth(buffer)), height: CGFloat(CVPixelBufferGetHeight(buffer)))
        let outputFlip = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: outputBounds.height)
        let image = canvas.transformed(by: request.renderContext.renderTransform)
            .transformed(by: outputFlip).cropped(to: outputBounds)
        context.render(image, to: buffer, bounds: outputBounds, colorSpace: colorSpace)
        return buffer
    }

    private static func failure() -> NSError {
        NSError(domain: "FrameletSoftwarePreview", code: 1,
            userInfo: [NSLocalizedDescriptionKey: "The recording preview could not be rendered. Original files have been retained."])
    }
}


@MainActor
private enum InstructionProbe {
    static func finite(_ value: Double) -> Double { value.isFinite ? value : -1 }

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
        let base = try SoftwareRecordingCompositor.videoComposition(from: built.videoComposition).mutableCopy() as! AVMutableVideoComposition
        base.customVideoCompositorClass = CountingOriginalCompositor.self
        let explicit = try ProtocolExperimentCompositor.videoComposition(from: built.videoComposition)
        let timed = explicit.mutableCopy() as! AVMutableVideoComposition
        timed.sourceTrackIDForFrameTiming = track.trackID
        let variants: [(String, AVVideoComposition?)] = [("raw", nil), ("standard", base), ("explicit", explicit), ("explicit-timed", timed)]
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
            for (phase, target) in [("red", 3.0), ("blue", 15.0)] {
                var seekFinished = false, seekSucceeded = false, playing = false
                player.seek(to: CMTime(seconds: target, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero) { completed in
                    Task { @MainActor in seekSucceeded = completed; seekFinished = true }
                }
                let started = ProcessInfo.processInfo.systemUptime
                var sample: [String: Any] = [:]
                while ProcessInfo.processInfo.systemUptime - started < 6 {
                    if seekFinished && seekSucceeded && !playing { player.play(); playing = true }
                    let current = player.currentTime()
                    if current.seconds >= target - 0.25 && current.seconds <= target + 5, pull.hasNewPixelBuffer(forItemTime: current) {
                        var display = CMTime.invalid
                        if let buffer = pull.copyPixelBuffer(forItemTime: current, itemTimeForDisplay: &display) {
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
                    ?? (item.customVideoCompositor as? ProtocolExperimentCompositor)?.requestCount ?? -1
                rows.append(["variant": name, "phase": phase, "requestedSeconds": target, "valid": valid, "validationError": validationError,
                    "seekFinished": seekFinished, "seekSucceeded": seekSucceeded, "playerTime": finite(player.currentTime().seconds),
                    "playerStatus": player.status.rawValue, "itemStatus": item.status.rawValue,
                    "playerError": player.error?.localizedDescription ?? "", "itemError": item.error?.localizedDescription ?? "",
                    "compositorType": item.customVideoCompositor.map { String(describing: type(of: $0)) } ?? "nil",
                    "requests": requests, "instructions": instructions(video), "frame": sample,
                    "sourceTrackIDForFrameTiming": video?.sourceTrackIDForFrameTiming ?? 0,
                    "elapsedSeconds": ProcessInfo.processInfo.systemUptime - started])
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
        let report: [String: Any] = ["kind": "framelet-instruction-delivery-probe", "measured": true,
            "rows": rows, "frames": frames, "productLaunched": false, "visibleWindowCreated": false,
            "captureOrExportRequested": false, "originalsModified": false,
            "renderAlgorithm": "Exact product drawing body, experimental instruction unwrapping only"]
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
private enum InstructionProbeMain {
    @MainActor static func main() {
        let application = NSApplication.shared
        application.setActivationPolicy(.prohibited)
        Task { @MainActor in
            do { try await InstructionProbe.run(); NSApp.terminate(nil) }
            catch { fputs("Instruction probe failed: \(error)\n", stderr); exit(1) }
        }
        application.run()
    }
}
