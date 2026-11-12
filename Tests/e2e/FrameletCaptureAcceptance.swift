import AppKit
import Foundation
import XCTest

// Actual owned-window capture. File/media inspection belongs to the host tool.
final class FrameletCaptureAcceptance: XCTestCase {
    @MainActor
    func testFUI03CapturePauseReopenAndExportOwnedWindow() throws {
        continueAfterFailure = false
        let configURL = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "FixtureConfig", withExtension: "json"))
        let config = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: configURL)) as? [String: String])
        let nonce = try XCTUnwrap(config["nonce"])
        let destination = try XCTUnwrap(config["root"])
        let title = "Framelet authored capture " + nonce
        let sourceLabel = "Window: " + title
        let app = XCUIApplication(bundleIdentifier: "com.alvarovillalbaa.Framelet")
        let fixture = XCUIApplication(bundleIdentifier: "com.alvarovillalbaa.FrameletAuthoredFixture")
        let system = XCUIApplication(bundleIdentifier: "com.apple.controlcenter")
        var captureRequested = false
        var stopRequested = false
        var shutdownAcknowledged = false
        var exportRequested = false
        var exportAcknowledged = false
        var times: [String: Double] = [:]
        func uptime() -> Double { ProcessInfo.processInfo.systemUptime }
        func interval(_ seconds: TimeInterval) {
            let end = uptime() + seconds
            while uptime() < end { RunLoop.current.run(until: Date().addingTimeInterval(0.1)) }
        }
        func wait(_ condition: @escaping () -> Bool, seconds: TimeInterval = 20) -> Bool {
            XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in condition() }, object: nil)],
                timeout: seconds) == .completed
        }
        func ready() -> Bool {
            app.staticTexts["Ready to record"].firstMatch.exists
                && app.buttons["Choose Source…"].firstMatch.exists
                && app.buttons["Choose Source…"].firstMatch.isEnabled
        }
        func libraryHidden() -> Bool {
            !app.windows.matching(NSPredicate(format: "identifier BEGINSWITH %@", "library-AppWindow-"))
                .allElementsBoundByIndex.contains { $0.isHittable }
        }
        func record(_ phase: String, picker: Bool = false) {
            let tree = XCTAttachment(string: app.debugDescription)
            tree.name = phase + ".accessibility"; tree.lifetime = .keepAlways; add(tree)
            if picker {
                let systemTree = XCTAttachment(string: system.debugDescription)
                systemTree.name = phase + "-system.accessibility"; systemTree.lifetime = .keepAlways; add(systemTree)
            }
            let image = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            image.name = phase; image.lifetime = .keepAlways; add(image)
        }
        func openRecordingMenu() {
            app.activate()
            app.menuBars.menuBarItems["Recording"].click()
        }
        func action(_ name: String) {
            openRecordingMenu()
            XCTAssertTrue(app.menuItems[name].waitForExistence(timeout: 15))
            XCTAssertTrue(app.menuItems[name].isEnabled)
            app.menuItems[name].click()
        }
        func expectMenuAction(_ name: String) {
            openRecordingMenu()
            XCTAssertTrue(wait { app.menuItems[name].exists && app.menuItems[name].isEnabled })
            app.typeKey(.escape, modifierFlags: [])
        }
        func show(_ element: XCUIElement) {
            XCTAssertTrue(element.waitForExistence(timeout: 15))
            for _ in 0..<6 {
                if element.isHittable { break }
                app.scrollViews.containing(.button, identifier: "Export…").firstMatch.scroll(byDeltaX: 0, deltaY: -250)
            }
            XCTAssertTrue(element.isHittable)
        }
        addTeardownBlock {
            await MainActor.run {
                if captureRequested && !shutdownAcknowledged && app.state != .notRunning {
                    app.activate()
                    if ready() { shutdownAcknowledged = true }
                    else {
                        // Foreground Stop is a normal user command. Never kill a
                        // recorder merely because a test or shutdown times out.
                        stopRequested = true
                        app.typeKey("s", modifierFlags: [.command, .shift])
                        shutdownAcknowledged = wait({ ready() }, seconds: 35)
                    }
                }
                var exportSettled = !exportRequested || exportAcknowledged
                if !exportSettled && app.state != .notRunning {
                    app.activate()
                    let cancel = app.buttons["Cancel Export"]
                    if cancel.exists {
                        for _ in 0..<6 {
                            if cancel.isHittable { break }
                            app.scrollViews.containing(.button, identifier: "Export…").firstMatch.scroll(byDeltaX: 0, deltaY: -250)
                        }
                        if cancel.isHittable { cancel.click() }
                    }
                    exportSettled = wait({
                        app.buttons["Export…"].exists && app.buttons["Export…"].isEnabled && !cancel.exists
                    }, seconds: 30)
                }
                let safeToTerminate = (!captureRequested || shutdownAcknowledged) && exportSettled
                record("diagnostic-final", picker: !captureRequested)
                let acknowledgment: [String: Any] = ["caseId": "FUI03", "captureRequested": captureRequested,
                    "stopRequested": stopRequested, "readyAndSourceControlsEnabled": shutdownAcknowledged,
                    "exportRequested": exportRequested, "exportSettled": exportSettled,
                    "safeToTerminate": safeToTerminate,
                    "observedUptime": uptime(), "forcedWriterTermination": false]
                if let bytes = try? JSONSerialization.data(withJSONObject: acknowledgment, options: [.sortedKeys, .prettyPrinted]) {
                    let attachment = XCTAttachment(data: bytes, uniformTypeIdentifier: "public.json")
                    attachment.name = "capture-shutdown"; attachment.lifetime = .keepAlways; self.add(attachment)
                }
                if safeToTerminate { app.terminate() }
                // No acknowledgment: leave app/library/partial files to the
                // controller's failed-preservation path, without app signals.
            }
        }

        XCTAssertTrue(fixture.windows[title].waitForExistence(timeout: 15))
        fixture.activate(); fixture.buttons["Authored Red"].click()
        app.launch()
        XCTAssertTrue(app.buttons["Choose Source…"].waitForExistence(timeout: 20))
        XCTAssertTrue(ready())
        XCTAssertFalse(app.buttons["Start"].isEnabled)
        for label in ["System audio", "Default microphone", "Default camera"] {
            let toggle = app.checkBoxes[label]
            XCTAssertTrue(toggle.exists)
            XCTAssertEqual((toggle.value as? NSNumber)?.intValue ?? Int(toggle.value as? String ?? ""), 0)
        }
        app.buttons["Choose Source…"].click()
        let picker = system.dialogs["Shared Content Picker Controls"]
        XCTAssertTrue(picker.buttons["Show All Windows"].waitForExistence(timeout: 15))
        record("01-picker-open", picker: true)
        picker.buttons["Show All Windows"].click()
        record("02-window-choices", picker: true)
        let ownedChoice = system.buttons.matching(NSPredicate(format: "label CONTAINS %@", title))
        XCTAssertTrue(ownedChoice.firstMatch.waitForExistence(timeout: 15))
        XCTAssertEqual(ownedChoice.count, 1)
        ownedChoice.firstMatch.click()
        if !app.staticTexts[sourceLabel].firstMatch.waitForExistence(timeout: 5) {
            record("03-window-confirmation", picker: true)
            let shareWindow = system.buttons.matching(NSPredicate(format:
                "label BEGINSWITH[c] %@ AND label CONTAINS[c] %@", "Share", "Window"))
            XCTAssertEqual(shareWindow.count, 1)
            shareWindow.firstMatch.click()
        }
        // The callback's selected-filter metadata, not a guessed tile, is the
        // final source guard. Never press Start for a generic/display source.
        XCTAssertTrue(app.staticTexts[sourceLabel].firstMatch.waitForExistence(timeout: 15))
        XCTAssertFalse(app.staticTexts["Selected display"].exists)
        XCTAssertTrue(app.buttons["Start"].isEnabled)
        record("04-owned-window-selected")

        times["startRequested"] = uptime(); captureRequested = true
        app.buttons["Start"].click()
        expectMenuAction("Pause Recording")
        XCTAssertTrue(wait { libraryHidden() })
        times["firstRecordingObserved"] = uptime()
        interval(3)
        record("05-red-recording")
        times["pauseRequested"] = uptime(); action("Pause Recording")
        expectMenuAction("Resume Recording")
        times["pauseReady"] = uptime()
        fixture.activate(); fixture.buttons["Authored Blue"].click()
        interval(4.5)
        record("06-paused-blue-fixture")
        times["resumeRequested"] = uptime(); action("Resume Recording")
        expectMenuAction("Pause Recording")
        XCTAssertTrue(wait { libraryHidden() })
        times["secondRecordingObserved"] = uptime()
        interval(3)
        record("07-blue-recording")
        times["stopRequested"] = uptime(); stopRequested = true; action("Stop Recording")
        XCTAssertTrue(wait({ ready() }, seconds: 35))
        times["finalReady"] = uptime(); shutdownAcknowledged = true
        XCTAssertTrue(app.buttons["Play Recording"].firstMatch.waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["Play Recording"].firstMatch.isEnabled)
        record("08-stop-acknowledged")
        // The host-owned observer hashes originals during this interval. Its
        // actual timestamp before Export must independently pass verification.
        interval(5)
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["Play Recording"].firstMatch.waitForExistence(timeout: 20))
        XCTAssertTrue(app.buttons["Play Recording"].firstMatch.isEnabled)
        XCTAssertTrue(app.buttons["Select clip 2"].exists)
        XCTAssertFalse(app.buttons["Select clip 3"].exists)
        let export = app.buttons["Export…"]; show(export)
        times["exportRequested"] = uptime(); export.click()
        let panel = app.windows["save-panel"]
        XCTAssertTrue(panel.textFields["saveAsNameTextField"].waitForExistence(timeout: 15))
        app.typeKey("g", modifierFlags: [.command, .shift]); app.typeText(destination); app.typeKey(.return, modifierFlags: [])
        let field = panel.textFields["saveAsNameTextField"]
        XCTAssertTrue(field.waitForExistence(timeout: 15)); field.click()
        app.typeKey("a", modifierFlags: .command); app.typeText("authored-window-export.mp4")
        exportRequested = true; panel.buttons["OKButton"].click()
        XCTAssertTrue(app.staticTexts["Most recent export: authored-window-export.mp4"].waitForExistence(timeout: 45))
        exportAcknowledged = true
        record("09-reopened-native-export")
        let observations: [String: Any] = ["caseId": "FUI03", "status": "passed", "fixtureTitle": title,
            "selectedSourceLabel": sourceLabel, "selectedSourceBeforeStart": true,
            "cameraMicrophoneSystemAudioOff": true, "reopenedClipCount": 2,
            "libraryHiddenForBothTakes": true,
            "nativeExportLabelObserved": true, "uptime": times, "fileVerificationOwner": "host controller"]
        let attachment = XCTAttachment(data: try JSONSerialization.data(withJSONObject: observations,
            options: [.sortedKeys, .prettyPrinted]), uniformTypeIdentifier: "public.json")
        attachment.name = "capture-observations"; attachment.lifetime = .keepAlways; add(attachment)
    }
}
