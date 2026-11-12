import AppKit
import AVKit
import CoreImage
import FrameletCore

// Read-only diagnostic variants, never replacement product acceptance.
@MainActor
private final class CompositionProbe: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var status: NSTextField!
    var timer: Timer?
    var players: [AVPlayer] = []
    var views: [AVPlayerView] = []
    var composition: RecordingComposition?
    var config: [String: String] = [:]
    var started = ProcessInfo.processInfo.systemUptime
    let names = ["Exact builder", "Explicit render scale 1", "Render scale 0.5", "Postprocessing disabled", "Software Core Image", "Raw assembled asset"]

    func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in
            do { try await open() }
            catch {
                fputs("Composition probe failed: \(error)\n", stderr)
                NSApp.terminate(nil)
            }
        }
    }

    func open() async throws {
        guard CommandLine.arguments.count == 2 else { throw CocoaError(.fileReadInvalidFileName) }
        config = try JSONDecoder().decode([String: String].self,
            from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])))
        guard let packagePath = config["package"], config["output"] != nil else { throw CocoaError(.fileReadCorruptFile) }
        let package = URL(fileURLWithPath: packagePath)
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let project = try decoder.decode(RecordingProject.self, from: Data(contentsOf: package.appendingPathComponent("manifest.json")))
        let built = try await RecordingCompositionBuilder.build(project: project, packageURL: package)
        composition = built
        let tracks = try await built.asset.loadTracks(withMediaType: .video)
        guard tracks.count == 1, let track = tracks.first else { throw CocoaError(.fileReadCorruptFile) }
        let unity = built.videoComposition.mutableCopy() as! AVMutableVideoComposition
        unity.renderScale = 1
        let half = built.videoComposition.mutableCopy() as! AVMutableVideoComposition
        half.renderScale = 0.5
        let noPost = built.videoComposition.mutableCopy() as! AVMutableVideoComposition
        noPost.instructions = try built.videoComposition.instructions.map { value in
            guard let original = value as? AVVideoCompositionInstruction else { throw CocoaError(.fileReadCorruptFile) }
            let instruction = AVMutableVideoCompositionInstruction()
            instruction.timeRange = original.timeRange; instruction.backgroundColor = original.backgroundColor
            instruction.layerInstructions = original.layerInstructions
            instruction.enablePostProcessing = false
            return instruction
        }
        let softwareContext = CIContext(options: [.useSoftwareRenderer: true])
        let software = AVMutableVideoComposition(asset: built.asset, applyingCIFiltersWithHandler: { request in
            request.finish(with: request.sourceImage, context: softwareContext)
        })
        let assets: [AVAsset] = Array(repeating: built.asset, count: 6)
        let videos: [AVVideoComposition?] = [built.videoComposition, unity, half, noPost, software, nil]
        window = NSWindow(contentRect: NSRect(x: 100, y: 140, width: 1500, height: 700),
            styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Framelet read-only composition diagnostic " + (config["nonce"] ?? "")
        window.isReleasedWhenClosed = false
        let content = NSView(frame: NSRect(x: 0, y: 0, width: 1500, height: 700))
        window.contentView = content
        status = NSTextField(labelWithString: "Read-only composition probe opening")
        status.frame = NSRect(x: 20, y: 670, width: 1460, height: 22); content.addSubview(status)
        for index in 0..<6 {
            let x = CGFloat(20 + (index % 3) * 490), y: CGFloat = index < 3 ? 350 : 20
            let label = NSTextField(labelWithString: names[index])
            label.frame = NSRect(x: x, y: y + 294, width: 470, height: 22); content.addSubview(label)
            let item = AVPlayerItem(asset: assets[index]); item.videoComposition = videos[index]
            item.audioMix = built.audioMix; item.forwardPlaybackEndTime = built.duration
            let player = AVPlayer(playerItem: item); player.isMuted = true; player.actionAtItemEnd = .pause
            players.append(player)
            let view = AVPlayerView(); view.controlsStyle = .none; view.player = player; view.videoGravity = .resizeAspect
            view.frame = NSRect(x: x, y: y, width: 470, height: 285)
            views.append(view); content.addSubview(view)
        }
        window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
        started = ProcessInfo.processInfo.systemUptime; players.forEach { $0.play() }
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.observe() }
        }
    }

    func observe() {
        let elapsed = ProcessInfo.processInfo.systemUptime - started
        guard players.allSatisfy({ $0.currentTime().seconds >= 3 }) || elapsed >= 15 else { return }
        timer?.invalidate(); timer = nil; players.forEach { $0.pause() }
        func rect(_ value: NSRect) -> [String: Double] {
            ["x": value.minX, "y": value.minY, "width": value.width, "height": value.height]
        }
        let rows: [[String: Any]] = players.indices.map { index in
            let player = players[index], view = views[index], item = player.currentItem!
            return ["name": names[index], "timeSeconds": player.currentTime().seconds,
                "playerStatus": player.status.rawValue, "itemStatus": item.status.rawValue,
                "playerError": player.error?.localizedDescription ?? "", "itemError": item.error?.localizedDescription ?? "",
                "renderScale": Double(item.videoComposition?.renderScale ?? -1),
                "frameDurationSeconds": item.videoComposition?.frameDuration.seconds ?? -1,
                "sourceTrackIDForFrameTiming": item.videoComposition?.sourceTrackIDForFrameTiming ?? -1,
                "instructionCount": item.videoComposition?.instructions.count ?? 0,
                "presentationSize": ["width": item.presentationSize.width, "height": item.presentationSize.height],
                "videoBounds": rect(view.videoBounds), "viewBounds": rect(view.bounds),
                "screenFrame": rect(window.convertToScreen(view.convert(view.bounds, to: nil)))]
        }
        let report: [String: Any] = ["kind": "read-only-composition-diagnostic", "elapsedSeconds": elapsed,
            "processID": ProcessInfo.processInfo.processIdentifier,
            "executablePath": Bundle.main.executableURL?.standardizedFileURL.path ?? "",
            "coordinateSystem": "AppKit screen points, origin bottom-left", "panes": rows,
            "captureOrExportRequested": false, "mediaModified": false, "shippingCodeModified": false]
        do {
            try JSONSerialization.data(withJSONObject: report, options: [.sortedKeys, .prettyPrinted])
                .write(to: URL(fileURLWithPath: config["output"]!), options: [.withoutOverwriting])
            status.stringValue = "Read-only composition probe ready"
        } catch { status.stringValue = "Read-only composition probe failed: " + error.localizedDescription }
    }
}

@main
private enum Main {
    @MainActor static func main() {
        let app = NSApplication.shared; app.setActivationPolicy(.regular)
        let delegate = CompositionProbe(); app.delegate = delegate
        let menu = NSMenu(), item = NSMenuItem(), commands = NSMenu()
        commands.addItem(withTitle: "Quit Composition Probe", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.submenu = commands; menu.addItem(item); app.mainMenu = menu
        withExtendedLifetime(delegate) { app.run() }
    }
}
