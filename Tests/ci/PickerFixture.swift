// Nonshipping, authored window for the disposable capture qualification VM.
import AppKit
import Foundation

@MainActor
final class AuthoredView: NSView {
    var blue = false
    override func draw(_ dirtyRect: NSRect) {
        (blue ? NSColor(calibratedRed: 0.05, green: 0.08, blue: 0.92, alpha: 1)
              : NSColor(calibratedRed: 0.92, green: 0.05, blue: 0.05, alpha: 1)).setFill()
        bounds.fill()
    }
}

@MainActor
final class FixtureDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow!
    private let colour = AuthoredView()
    private var counter = 0
    private var timer: Timer?
    private let marker = NSTextField(labelWithString: "Authored tick 0")

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard CommandLine.arguments.count == 2,
              CommandLine.arguments[1].range(of: "^[a-f0-9]{32}$", options: .regularExpression) != nil else {
            NSApp.terminate(nil); return
        }
        let nonce = CommandLine.arguments[1]
        window = NSWindow(contentRect: NSRect(x: 100, y: 140, width: 640, height: 400),
            styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "Framelet authored capture " + nonce
        window.identifier = NSUserInterfaceItemIdentifier("FrameletAuthoredFixture-" + nonce)
        let content = NSView(frame: NSRect(x: 0, y: 0, width: 640, height: 400))
        colour.frame = NSRect(x: 0, y: 0, width: 640, height: 340)
        content.addSubview(colour)
        let red = NSButton(title: "Authored Red", target: self, action: #selector(red))
        let blue = NSButton(title: "Authored Blue", target: self, action: #selector(blue))
        let controls = NSStackView(views: [red, blue, marker])
        controls.spacing = 16; controls.frame = NSRect(x: 16, y: 350, width: 610, height: 32)
        content.addSubview(controls)
        window.contentView = content
        let menu = NSMenu()
        let item = NSMenuItem(); menu.addItem(item)
        let appMenu = NSMenu(); item.submenu = appMenu
        appMenu.addItem(withTitle: "Quit Authored Fixture", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        NSApp.mainMenu = menu
        NSApp.setActivationPolicy(.regular)
        window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.counter += 1; self.marker.stringValue = "Authored tick \(self.counter)"
            }
        }
    }

    @objc private func red() { colour.blue = false; colour.needsDisplay = true }
    @objc private func blue() { colour.blue = true; colour.needsDisplay = true }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

@main @MainActor
struct PickerFixture {
    static func main() {
        let delegate = FixtureDelegate()
        let app = NSApplication.shared
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
