import AppKit
import AVKit
import CoreImage
import CoreVideo
import CryptoKit
import FrameletCore
import ImageIO
import UniformTypeIdentifiers

// Experimental pool attributes only. Production compositor bytes stay exact.
private final class SurfacePoolCompositor: NSObject, AVVideoCompositing, @unchecked Sendable {
    private let original = SoftwareRecordingCompositor()
    private let lock = NSLock()
    private var requests = 0
    var requestCount: Int { lock.lock(); defer { lock.unlock() }; return requests }
    var sourcePixelBufferAttributes: [String: any Sendable]? { original.sourcePixelBufferAttributes }
    var requiredPixelBufferAttributesForRenderContext: [String: any Sendable] {
        [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
         kCVPixelBufferIOSurfacePropertiesKey as String: [String: Int](),
         kCVPixelBufferMetalCompatibilityKey as String: true]
    }
    func renderContextChanged(_ context: AVVideoCompositionRenderContext) { original.renderContextChanged(context) }
    func startRequest(_ request: AVAsynchronousVideoCompositionRequest) {
        lock.lock(); requests += 1; lock.unlock(); original.startRequest(request)
    }
    func cancelAllPendingVideoCompositionRequests() { original.cancelAllPendingVideoCompositionRequests() }
}

@MainActor
private final class PlayerOutputProbe: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var status: NSTextField!
    var blue: NSButton!
    var imageView: NSImageView!
    var players: [AVPlayer] = []
    var views: [AVPlayerView] = []
    var outputs: [Int: AVPlayerItemVideoOutput] = [:]
    var images: [Int: CGImage] = [:]
    var buffers: [Int: [String: Any]] = [:]
    var received: [Int: Int] = [:]
    var timer: Timer?
    var composition: RecordingComposition?
    var config: [String: String] = [:]
    var directory: URL!
    var phase = "red"
    var requested: Double = 3
    var started: Double = 0
    var generation = 0
    var completedGeneration = -1
    let context = CIContext(options: [.useSoftwareRenderer: true, .cacheIntermediates: false])

    func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in
            do { try await open() }
            catch { fputs("Player output probe failed: \(error)\n", stderr); NSApp.terminate(nil) }
        }
    }

    func open() async throws {
        guard CommandLine.arguments.count == 2 else { throw CocoaError(.fileReadInvalidFileName) }
        config = try JSONDecoder().decode([String: String].self,
            from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])))
        guard let packagePath = config["package"], let output = config["output"] else { throw CocoaError(.fileReadCorruptFile) }
        directory = URL(fileURLWithPath: output)
        guard !FileManager.default.fileExists(atPath: output) else { throw CocoaError(.fileWriteFileExists) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        let package = URL(fileURLWithPath: packagePath)
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let project = try decoder.decode(RecordingProject.self, from: Data(contentsOf: package.appendingPathComponent("manifest.json")))
        let built = try await RecordingCompositionBuilder.build(project: project, packageURL: package)
        composition = built
        for index in 0..<4 {
            let item = AVPlayerItem(asset: built.asset)
            if index < 3 {
                let video = try SoftwareRecordingCompositor.videoComposition(from: built.videoComposition)
                if index == 2 {
                    guard let compatible = video.mutableCopy() as? AVMutableVideoComposition else { throw CocoaError(.fileReadCorruptFile) }
                    compatible.customVideoCompositorClass = SurfacePoolCompositor.self
                    item.videoComposition = compatible
                } else { item.videoComposition = video }
            }
            item.audioMix = built.audioMix; item.forwardPlaybackEndTime = built.duration
            if index == 1 || index == 3 {
                let output = AVPlayerItemVideoOutput(pixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
                output.suppressesPlayerRendering = false; item.add(output); outputs[index] = output
            }
            let player = AVPlayer(playerItem: item); player.isMuted = true; player.actionAtItemEnd = .pause
            players.append(player)
        }
        window = NSWindow(contentRect: NSRect(x: 100, y: 140, width: 1500, height: 700),
            styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Framelet player output diagnostic " + (config["nonce"] ?? "")
        window.isReleasedWhenClosed = false
        let content = NSView(frame: NSRect(x: 0, y: 0, width: 1500, height: 700)); window.contentView = content
        status = NSTextField(labelWithString: "Player output probe opening")
        status.frame = NSRect(x: 20, y: 670, width: 1200, height: 22); content.addSubview(status)
        blue = NSButton(title: "Show blue", target: self, action: #selector(showBlue))
        blue.frame = NSRect(x: 1300, y: 663, width: 170, height: 30); blue.isEnabled = false; content.addSubview(blue)
        let names = ["A · Production compositor, plain AVPlayerView", "B · Same compositor + video output",
            "C · B's copied buffer in NSImageView", "D · IOSurface / Metal pool AVPlayerView"]
        for pane in 0..<4 {
            let x = CGFloat(20 + (pane % 2) * 740), y: CGFloat = pane < 2 ? 350 : 20
            let label = NSTextField(labelWithString: names[pane])
            label.frame = NSRect(x: x, y: y + 294, width: 720, height: 22); content.addSubview(label)
            let frame = NSRect(x: x, y: y, width: 720, height: 285)
            if pane == 2 {
                imageView = NSImageView(frame: frame); imageView.imageScaling = .scaleProportionallyUpOrDown
                content.addSubview(imageView)
            } else {
                let index = pane == 3 ? 2 : pane
                let view = AVPlayerView(frame: frame); view.controlsStyle = .none
                view.videoGravity = .resizeAspect; view.player = players[index]
                views.append(view); content.addSubview(view)
            }
        }
        window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
        begin("red", at: 3)
    }

    @objc func showBlue() { begin("blue", at: 15) }

    func begin(_ name: String, at seconds: Double) {
        generation += 1; let token = generation
        timer?.invalidate(); players.forEach { $0.pause() }
        phase = name; requested = seconds; started = ProcessInfo.processInfo.systemUptime
        images.removeAll(); buffers.removeAll(); received.removeAll(); imageView.image = nil
        blue.isEnabled = false; status.stringValue = "Player output probe " + name + " opening"
        outputs.values.forEach { $0.requestNotificationOfMediaDataChange(withAdvanceInterval: 0.1) }
        for player in players {
            player.seek(to: CMTime(seconds: seconds, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero) { [weak self, weak player] completed in
                Task { @MainActor in if self?.generation == token, completed { player?.play() } }
            }
        }
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.observe() }
        }
    }

    func collect() {
        for (index, output) in outputs {
            let current = players[index].currentTime()
            guard current.seconds >= requested - 0.2, current.seconds <= requested + 5,
                  output.hasNewPixelBuffer(forItemTime: current) else { continue }
            var displayed = CMTime.invalid
            guard let buffer = output.copyPixelBuffer(forItemTime: current, itemTimeForDisplay: &displayed) else { continue }
            received[index, default: 0] += 1
            let read = readPixels(buffer)
            buffers[index] = ["currentSeconds": finite(current.seconds), "displayedSeconds": finite(displayed.seconds),
                "width": CVPixelBufferGetWidth(buffer), "height": CVPixelBufferGetHeight(buffer),
                "pixelFormat": CVPixelBufferGetPixelFormatType(buffer), "pixelReadStatus": read.status,
                "iosurfaceBacked": CVPixelBufferGetIOSurface(buffer) != nil, "medianRGB": read.rgb,
                "framesReceived": received[index, default: 0], "cgImageProduced": false]
            let image = CIImage(cvPixelBuffer: buffer)
            guard let cg = context.createCGImage(image, from: image.extent), let rgb = try? sample(cg) else { continue }
            images[index] = cg; buffers[index]?["cgImageProduced"] = true; buffers[index]?["imageMedianRGB"] = rgb
            if index == 1 { imageView.image = NSImage(cgImage: cg, size: NSSize(width: CGFloat(cg.width), height: CGFloat(cg.height))) }
        }
    }

    func observe() {
        guard completedGeneration != generation else { return }
        collect()
        let elapsed = ProcessInfo.processInfo.systemUptime - started
        guard players.allSatisfy({ $0.currentTime().seconds >= requested + 0.3 }) || elapsed >= 15 else { return }
        completedGeneration = generation
        timer?.invalidate(); timer = nil; players.forEach { $0.pause() }; collect()
        do {
            var frames: [[String: Any]] = []
            for (index, image) in images.sorted(by: { $0.key < $1.key }) {
                let name = phase + (index == 1 ? "-output.png" : "-raw.png")
                let url = directory.appendingPathComponent(name)
                guard !FileManager.default.fileExists(atPath: url.path) else { throw CocoaError(.fileWriteFileExists) }
                guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else { throw CocoaError(.fileWriteUnknown) }
                CGImageDestinationAddImage(destination, image, nil)
                guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
                let raw = try Data(contentsOf: url)
                guard raw.count <= 2 * 1024 * 1024 else { throw CocoaError(.fileWriteOutOfSpace) }
                frames.append(["name": name, "bytes": raw.count,
                    "sha256": SHA256.hash(data: raw).map { String(format: "%02x", $0) }.joined()])
            }
            func rect(_ value: NSRect) -> [String: Double] {
                ["x": value.minX, "y": value.minY, "width": value.width, "height": value.height]
            }
            let rows: [[String: Any]] = players.indices.map { index in
                let player = players[index], item = player.currentItem!
                return ["index": index, "timeSeconds": finite(player.currentTime().seconds),
                    "playerStatus": player.status.rawValue, "itemStatus": item.status.rawValue,
                    "playerError": player.error?.localizedDescription ?? "", "itemError": item.error?.localizedDescription ?? "",
                    "compositorType": item.customVideoCompositor.map { String(describing: type(of: $0)) } ?? "nil",
                    "compatibleRequests": (item.customVideoCompositor as? SurfacePoolCompositor)?.requestCount ?? -1,
                    "copiedBuffer": buffers[index] ?? [:]]
            }
            let report: [String: Any] = ["kind": "read-only-player-output-diagnostic", "phase": phase,
                "nonce": config["nonce"] ?? "", "requestedSeconds": requested, "elapsedSeconds": elapsed,
                "processID": ProcessInfo.processInfo.processIdentifier,
                "executablePath": Bundle.main.executableURL?.standardizedFileURL.path ?? "",
                "displayBounds": rect(window.screen?.frame ?? .zero), "windowFrame": rect(window.frame),
                "windowVisible": window.isVisible, "applicationActive": NSApp.isActive,
                "players": rows, "frames": frames,
                "viewScreenFrames": views.map { rect(window.convertToScreen($0.convert($0.bounds, to: nil))) },
                "imageScreenFrame": rect(window.convertToScreen(imageView.convert(imageView.bounds, to: nil))),
                "captureOrExportRequested": false, "mediaModified": false, "shippingCodeModified": false]
            try JSONSerialization.data(withJSONObject: report, options: [.sortedKeys, .prettyPrinted])
                .write(to: directory.appendingPathComponent(phase + ".json"), options: [.withoutOverwriting])
            status.stringValue = "Player output probe " + phase + " ready"
            blue.isEnabled = phase == "red"
        } catch { status.stringValue = "Player output probe failed: " + error.localizedDescription }
    }

    func finite(_ value: Double) -> Double { value.isFinite ? value : -1 }

    func readPixels(_ buffer: CVPixelBuffer) -> (status: Int, rgb: [Int]) {
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

    func sample(_ image: CGImage) throws -> [Int] {
        guard let crop = image.cropping(to: CGRect(x: Double(image.width) * 0.5 - 8, y: Double(image.height) * 0.6 - 8, width: 16, height: 16)) else { throw CocoaError(.coderReadCorrupt) }
        var values = [UInt8](repeating: 0, count: 16 * 16 * 4)
        let rendered = values.withUnsafeMutableBytes { data -> Bool in
            guard let context = CGContext(data: data.baseAddress, width: 16, height: 16, bitsPerComponent: 8,
                bytesPerRow: 64, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else { return false }
            context.draw(crop, in: CGRect(x: 0, y: 0, width: 16, height: 16)); return true
        }
        guard rendered else { throw CocoaError(.coderReadCorrupt) }
        return (0..<3).map { channel in stride(from: channel, to: values.count, by: 4).map { Int(values[$0]) }.sorted()[128] }
    }

    func applicationWillTerminate(_ notification: Notification) { timer?.invalidate(); players.forEach { $0.pause() } }
}

@main
private enum PlayerOutputMain {
    @MainActor static func main() {
        let app = NSApplication.shared; app.setActivationPolicy(.regular)
        let delegate = PlayerOutputProbe(); app.delegate = delegate
        let menu = NSMenu(), item = NSMenuItem(), commands = NSMenu()
        commands.addItem(withTitle: "Quit Player Output Probe", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.submenu = commands; menu.addItem(item); app.mainMenu = menu
        withExtendedLifetime(delegate) { app.run() }
    }
}
