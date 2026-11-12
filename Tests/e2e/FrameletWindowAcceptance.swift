import AppKit
import CoreGraphics
import Foundation
import XCTest

final class FrameletWindowAcceptance: XCTestCase {
    @MainActor
    func testFUI02WindowsFitDisplayAfterRelaunch() throws {
        continueAfterFailure = false
        let configURL = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "FixtureConfig", withExtension: "json"))
        let config = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: configURL)) as? [String: Any])
        let bounds = try XCTUnwrap(config["visibleRect"] as? [String: Double])
        let fullWidth = try XCTUnwrap(config["fullWidth"] as? Double)
        let fullHeight = try XCTUnwrap(config["fullHeight"] as? Double)
        let available = CGRect(x: try XCTUnwrap(bounds["x"]), y: try XCTUnwrap(bounds["y"]),
            width: try XCTUnwrap(bounds["width"]), height: try XCTUnwrap(bounds["height"]))
        XCTAssertGreaterThanOrEqual(available.width, 900)
        XCTAssertLessThan(available.width, 1180)
        let app = XCUIApplication(bundleIdentifier: "com.alvarovillalbaa.Framelet")
        let windows = app.windows.matching(NSPredicate(format: "identifier BEGINSWITH %@", "library-AppWindow-"))
        var phases: [[String: Any]] = []
        func visibleRect() -> CGRect {
            let screens = NSScreen.screens
            guard screens.count == 1, let screen = screens.first,
                  Double(screen.frame.width) == fullWidth,
                  Double(screen.frame.height) == fullHeight else { return .zero }
            let rect = screen.visibleFrame
            return CGRect(x: rect.minX, y: screen.frame.maxY - rect.maxY, width: rect.width, height: rect.height)
        }
        func record(_ name: String) {
            let tree = XCTAttachment(string: app.debugDescription)
            tree.name = name + ".accessibility"; tree.lifetime = .keepAlways; add(tree)
            let image = XCTAttachment(screenshot: app.screenshot())
            image.name = name; image.lifetime = .keepAlways; add(image)
        }
        func fits(_ frame: CGRect, in available: CGRect) -> Bool {
            frame.width.isFinite && frame.height.isFinite && frame.origin.x.isFinite && frame.origin.y.isFinite
                && frame.width >= 900 && frame.height >= 640
                && frame.minX >= available.minX - 1 && frame.minY >= available.minY - 1
                && frame.maxX <= available.maxX + 1 && frame.maxY <= available.maxY + 1
        }
        func check(_ name: String, count: Int?) {
            XCTAssertTrue(windows.firstMatch.waitForExistence(timeout: 20))
            let settled = NSPredicate { _, _ in
                let current = visibleRect()
                return windows.count >= 1 && windows.count <= 2
                    && windows.allElementsBoundByIndex.allSatisfy { fits($0.frame, in: current) }
                    && (count == nil || windows.count == count)
            }
            XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: settled, object: nil)], timeout: 15), .completed)
            let current = visibleRect()
            let frames = windows.allElementsBoundByIndex.map { window -> [String: Any] in
                let frame = window.frame
                XCTAssertTrue(fits(frame, in: current))
                return ["identifier": window.identifier, "x": frame.minX, "y": frame.minY,
                    "width": frame.width, "height": frame.height]
            }
            XCTAssertEqual(current, visibleRect())
            XCTAssertTrue(app.staticTexts["Authored UI recording"].firstMatch.exists)
            let previewReady = NSPredicate { _, _ in
                app.buttons["Play Recording"].firstMatch.exists && app.buttons["Play Recording"].firstMatch.isEnabled
            }
            XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: previewReady, object: nil)], timeout: 15), .completed)
            XCTAssertFalse(app.staticTexts["Recording unavailable"].exists)
            phases.append(["name": name, "frames": frames,
                "visibleRect": ["x": current.minX, "y": current.minY,
                    "width": current.width, "height": current.height]])
            record(name)
        }
        addTeardownBlock {
            await MainActor.run {
                if app.state == .runningForeground {
                    let screens = NSScreen.screens
                    let display = screens.map { screen in
                        ["x": screen.visibleFrame.minX, "y": screen.frame.maxY - screen.visibleFrame.maxY,
                            "width": screen.visibleFrame.width, "height": screen.visibleFrame.height]
                    }
                    if let data = try? JSONSerialization.data(withJSONObject: display, options: .sortedKeys) {
                        let metadata = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
                        metadata.name = "diagnostic-display"; metadata.lifetime = .keepAlways; self.add(metadata)
                    }
                    let tree = XCTAttachment(string: app.debugDescription)
                    tree.name = "diagnostic-final.accessibility"; tree.lifetime = .keepAlways; self.add(tree)
                    let image = XCTAttachment(screenshot: app.screenshot())
                    image.name = "diagnostic-final"; image.lifetime = .keepAlways; self.add(image)
                }
                app.terminate()
            }
        }
        app.launch()
        XCTAssertTrue(app.buttons["Play Recording"].firstMatch.waitForExistence(timeout: 20))
        check("01-first-window", count: 1)
        app.terminate(); app.launch()
        check("02-reopened-window", count: 1)
        app.menuBars.menuBarItems["File"].click()
        app.menuItems["New Framelet Window"].click()
        check("03-additional-window", count: 2)
        app.terminate(); app.launch()
        // Respect macOS's restoration preference: either one or two may reopen.
        check("04-reopened-windows", count: nil)
        let observations: [String: Any] = ["caseId": "FUI02", "status": "passed",
            "initialVisibleRect": bounds, "phases": phases, "sourcePickerOpened": false,
            "capturePerformed": false, "recordingEditsPerformed": false]
        let attachment = XCTAttachment(data: try JSONSerialization.data(withJSONObject: observations,
            options: [.sortedKeys, .prettyPrinted]), uniformTypeIdentifier: "public.json")
        attachment.name = "window-observations"; attachment.lifetime = .keepAlways; add(attachment)
    }
}
