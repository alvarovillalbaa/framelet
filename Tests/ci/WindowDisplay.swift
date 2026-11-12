// Nonshipping CI metadata reader. No windows, capture or device permissions.
import AppKit
import Foundation

@main @MainActor
struct WindowDisplay {
    static func main() throws {
        let screens = NSScreen.screens
        guard screens.count == 1, let screen = screens.first else {
            fatalError("This regression requires the reviewed single-display VM")
        }
        let visible = screen.visibleFrame
        guard visible.width >= 900, visible.width < 1180, visible.height >= 640 else {
            fatalError("The display does not reproduce the observed small-screen condition")
        }
        // XCTest window rectangles use the main display's top-left origin.
        let bounds: [String: Double] = ["x": visible.minX, "y": screen.frame.maxY - visible.maxY,
            "width": visible.width, "height": visible.height]
        let result: [String: Any] = ["visibleRect": bounds, "displayCount": screens.count,
            "fullWidth": screen.frame.width, "fullHeight": screen.frame.height]
        print(String(data: try JSONSerialization.data(withJSONObject: result, options: .sortedKeys), encoding: .utf8)!)
    }
}
