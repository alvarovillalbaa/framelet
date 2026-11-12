import CoreGraphics
import Foundation
import XCTest

// UI actions/observations only. This sandboxed runner neither seeds nor reads
// the production app's library; the owning CI controller verifies its fixtures.
final class FrameletAcceptance: XCTestCase {
    @MainActor
    func testFUI01EditReopenAndExportNativeRecording() throws {
        continueAfterFailure = false
        let configURL = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "FixtureConfig", withExtension: "json"))
        let config = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: configURL)) as? [String: String])
        let destinationFolder = try XCTUnwrap(config["root"])
        let app = XCUIApplication(bundleIdentifier: "com.alvarovillalbaa.Framelet")
        func record(_ phase: String) {
            let hierarchy = XCTAttachment(string: app.debugDescription); hierarchy.name = phase + ".accessibility"
            hierarchy.lifetime = .keepAlways; add(hierarchy)
            let image = XCTAttachment(screenshot: app.screenshot()); image.name = phase
            image.lifetime = .keepAlways; add(image)
        }
        func wait(_ condition: @escaping () -> Bool, timeout: TimeInterval = 15) {
            XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in condition() }, object: nil)], timeout: timeout), .completed)
        }
        func show(_ element: XCUIElement) {
            XCTAssertTrue(element.waitForExistence(timeout: 15))
            for _ in 0..<6 {
                if element.isHittable { break }
                app.scrollViews.containing(.button, identifier: "Export…").firstMatch.scroll(byDeltaX: 0, deltaY: -250)
            }
            XCTAssertTrue(element.isHittable)
        }
        func replace(_ field: XCUIElement, with value: String) {
            show(field); field.click(); app.typeKey("a", modifierFlags: .command); app.typeText(value)
        }
        func clip(_ index: Int) -> XCUIElement { app.buttons["Select clip \(index)"] }
        addTeardownBlock {
            await MainActor.run {
                if app.state == .runningForeground {
                    let tree = XCTAttachment(string: app.debugDescription)
                    tree.name = "diagnostic-final.accessibility"; tree.lifetime = .keepAlways; self.add(tree)
                    let image = XCTAttachment(screenshot: app.screenshot())
                    image.name = "diagnostic-final"; image.lifetime = .keepAlways; self.add(image)
                }
                app.terminate()
            }
        }
        app.launch()
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 20))
        XCTAssertTrue(app.staticTexts["Authored UI recording"].firstMatch.waitForExistence(timeout: 15))
        wait { app.buttons["Play Recording"].exists && app.buttons["Play Recording"].isEnabled }
        XCTAssertFalse(app.staticTexts["Recording unavailable"].exists)
        record("01-library-preview")

        app.popUpButtons["Recording Actions"].click()
        app.menuItems["Rename…"].click()
        replace(app.textFields["Recording title"], with: "Authored edited recording")
        app.buttons["Save"].click()
        XCTAssertTrue(app.staticTexts["Authored edited recording"].firstMatch.waitForExistence(timeout: 15))
        replace(app.textFields["Start (seconds)"], with: "0.2")
        replace(app.textFields["End (seconds)"], with: "0.6")
        app.buttons["Apply Trim"].click()
        wait { clip(1).value as? String == "0.20–0.60 seconds; duration 0:00" }
        app.buttons["Duplicate clip 1"].click()
        XCTAssertTrue(clip(3).waitForExistence(timeout: 15))
        app.buttons["Move clip 2 later"].click()
        wait { clip(2).value as? String == "0.20–1.00 seconds; duration 0:00" }
        app.buttons["Remove clip 3 from edit"].click()
        wait { !clip(3).exists }
        app.buttons["Move clip 2 earlier"].click()
        wait { clip(1).value as? String == "0.20–1.00 seconds; duration 0:00" }
        XCTAssertEqual(clip(2).value as? String, "0.20–0.60 seconds; duration 0:00")
        record("02-edited-clips")

        let disclosure = app.disclosureTriangles["Canvas and camera layout"]
        show(disclosure)
        disclosure.coordinate(withNormalizedOffset: CGVector(dx: 0.14, dy: 0.5)).click()
        wait {
            if let number = disclosure.value as? NSNumber { return number.intValue == 1 }
            return disclosure.value as? String == "1"
        }
        let canvas = app.popUpButtons["Canvas"]
        show(canvas); canvas.click(); app.menuItems["Square"].click()
        XCTAssertEqual(app.popUpButtons["Layout"].value as? String, "Screen")
        app.popUpButtons["Background"].click(); app.menuItems["Sand"].click()
        let applyCanvas = app.buttons["Apply Canvas"]
        show(applyCanvas); XCTAssertTrue(applyCanvas.isEnabled); applyCanvas.click()
        wait { !applyCanvas.isEnabled }
        let exportButton = app.buttons["Export…"]
        show(exportButton); XCTAssertTrue(exportButton.isEnabled); exportButton.click()
        let savePanel = app.windows["save-panel"]
        XCTAssertTrue(savePanel.textFields["saveAsNameTextField"].waitForExistence(timeout: 15))
        app.typeKey("g", modifierFlags: [.command, .shift]); app.typeText(destinationFolder); app.typeKey(.return, modifierFlags: [])
        let save = savePanel.buttons["OKButton"]
        XCTAssertTrue(save.waitForExistence(timeout: 15))
        replace(savePanel.textFields["saveAsNameTextField"], with: "authored-ui-export.mp4")
        save.click()
        XCTAssertTrue(app.staticTexts["Most recent export: authored-ui-export.mp4"].waitForExistence(timeout: 30))
        record("03-native-export")

        app.terminate(); app.launch()
        XCTAssertTrue(app.staticTexts["Authored edited recording"].firstMatch.waitForExistence(timeout: 20))
        wait { app.buttons["Play Recording"].exists && app.buttons["Play Recording"].isEnabled }
        show(clip(1))
        XCTAssertEqual(clip(1).value as? String, "0.20–1.00 seconds; duration 0:00")
        XCTAssertEqual(clip(2).value as? String, "0.20–0.60 seconds; duration 0:00")
        XCTAssertFalse(clip(3).exists)
        record("04-reopened-library")
        let observation: [String: Any] = ["caseId": "FUI01", "status": "passed",
            "nativeExportLabelObserved": true, "reopenedTitleObserved": true, "reopenedClipCount": 2,
            "clipRanges": ["0.20–1.00", "0.20–0.60"], "fileVerificationOwner": "CI fixture controller"]
        let attachment = XCTAttachment(data: try JSONSerialization.data(withJSONObject: observation, options: [.sortedKeys, .prettyPrinted]), uniformTypeIdentifier: "public.json")
        attachment.name = "ui-observations"; attachment.lifetime = .keepAlways; add(attachment)
    }
}
