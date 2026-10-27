import AppKit

@MainActor
final class UIWindowRegistry {
    private let windows = NSHashTable<NSWindow>.weakObjects()
    private var minimized = Set<ObjectIdentifier>()

    func register(_ window: NSWindow) { windows.add(window) }

    func minimizeForRecording() {
        for window in windows.allObjects where window.isVisible && !window.isMiniaturized {
            minimized.insert(ObjectIdentifier(window))
            window.miniaturize(nil)
        }
    }

    @discardableResult
    func restore() -> Bool {
        let available = windows.allObjects.filter { $0.isVisible || $0.isMiniaturized }
        for window in available where minimized.contains(ObjectIdentifier(window)) {
            window.deminiaturize(nil)
        }
        minimized.removeAll()
        if let window = available.first { window.makeKeyAndOrderFront(nil) }
        if !available.isEmpty { NSApp.activate(ignoringOtherApps: true) }
        return !available.isEmpty
    }
}
