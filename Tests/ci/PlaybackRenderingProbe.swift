import AppKit
import AVKit
import SwiftUI

// A separate, disposable read-only diagnostic. No Framelet code or media writes.
@MainActor
private struct EmbeddedPlayer: NSViewRepresentable {
    let view: AVPlayerView
    func makeNSView(context: Context) -> AVPlayerView { view }
    func updateNSView(_ view: AVPlayerView, context: Context) {}
}

@MainActor
private final class Probe: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var timer: Timer?
    var players: [AVPlayer] = []
    var views: [AVPlayerView] = []
    var panes: [NSView] = []
    var status: NSTextField!
    var config: [String: String] = [:]
    var started = ProcessInfo.processInfo.systemUptime
    let names = ["Plain AppKit red", "Plain AppKit blue", "SwiftUI red", "Clipped SwiftUI red"]

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            guard CommandLine.arguments.count == 2 else { throw CocoaError(.fileReadInvalidFileName) }
            let bytes = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
            config = try JSONDecoder().decode([String: String].self, from: bytes)
            guard let red = config["red"], let blue = config["blue"], config["output"] != nil else {
                throw CocoaError(.fileReadCorruptFile)
            }
            window = NSWindow(contentRect: NSRect(x: 100, y: 140, width: 1200, height: 700),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.title = "Framelet read-only rendering diagnostic " + (config["nonce"] ?? "")
            window.isReleasedWhenClosed = false
            let content = NSView(frame: NSRect(x: 0, y: 0, width: 1200, height: 700))
            window.contentView = content
            status = NSTextField(labelWithString: "Read-only rendering probe opening")
            status.frame = NSRect(x: 20, y: 670, width: 1160, height: 22); content.addSubview(status)
            for index in 0..<4 {
                let x = CGFloat(20 + (index % 2) * 590), y: CGFloat = index < 2 ? 350 : 20
                let label = NSTextField(labelWithString: names[index])
                label.frame = NSRect(x: x, y: y + 294, width: 570, height: 22); content.addSubview(label)
                let player = AVPlayer(url: URL(fileURLWithPath: index == 1 ? blue : red))
                player.isMuted = true; player.actionAtItemEnd = .pause; players.append(player)
                let view = AVPlayerView(); view.controlsStyle = .none
                view.player = player; view.videoGravity = .resizeAspect; views.append(view)
                let pane: NSView
                if index < 2 { pane = view }
                else if index == 2 { pane = NSHostingView(rootView: EmbeddedPlayer(view: view)) }
                else { pane = NSHostingView(rootView: EmbeddedPlayer(view: view).clipShape(RoundedRectangle(cornerRadius: 10))) }
                pane.frame = NSRect(x: x, y: y, width: 570, height: 285)
                content.addSubview(pane); panes.append(pane)
            }
            window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
            started = ProcessInfo.processInfo.systemUptime
            players.forEach { $0.play() }
            timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.observe() }
            }
        } catch {
            fputs("Rendering probe could not open authored inputs: \(error)\n", stderr)
            NSApp.terminate(nil)
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
            let player = players[index], view = views[index], pane = panes[index]
            return ["name": names[index], "timeSeconds": player.currentTime().seconds,
                    "playerStatus": player.status.rawValue, "itemStatus": player.currentItem?.status.rawValue ?? -1,
                    "playerError": player.error?.localizedDescription ?? "", "itemError": player.currentItem?.error?.localizedDescription ?? "",
                    "videoBounds": rect(view.videoBounds), "viewBounds": rect(view.bounds),
                    "screenFrame": rect(window.convertToScreen(pane.convert(pane.bounds, to: nil)))]
        }
        let report: [String: Any] = ["kind": "read-only-rendering-diagnostic", "elapsedSeconds": elapsed,
            "coordinateSystem": "AppKit screen points, origin bottom-left", "panes": rows,
            "captureOrExportRequested": false, "mediaModified": false]
        do {
            let data = try JSONSerialization.data(withJSONObject: report, options: [.sortedKeys, .prettyPrinted])
            try data.write(to: URL(fileURLWithPath: config["output"]!), options: [.withoutOverwriting])
            status.stringValue = "Read-only rendering probe ready"
        } catch { status.stringValue = "Read-only rendering probe failed: " + error.localizedDescription }
    }
}

@main
private enum Main {
    @MainActor static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        let delegate = Probe(); app.delegate = delegate
        let menu = NSMenu(), item = NSMenuItem(), commands = NSMenu()
        commands.addItem(withTitle: "Quit Rendering Probe", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.submenu = commands; menu.addItem(item); app.mainMenu = menu
        withExtendedLifetime(delegate) { app.run() }
    }
}
