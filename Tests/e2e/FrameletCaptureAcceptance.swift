import AppKit
import CoreGraphics
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
        var quitRequested = false
        var quitAcknowledged = false
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
        func openRecordingMenu() -> XCUIElement {
            app.activate()
            let item = app.menuBars.menuBarItems["Recording"]
            item.click()
            return item.menus.firstMatch
        }
        func action(_ name: String) {
            let menu = openRecordingMenu()
            XCTAssertTrue(menu.menuItems[name].waitForExistence(timeout: 15))
            XCTAssertTrue(menu.menuItems[name].isEnabled)
            menu.menuItems[name].click()
        }
        func expectMenuAction(_ name: String) {
            let menu = openRecordingMenu()
            XCTAssertTrue(wait { menu.menuItems[name].exists && menu.menuItems[name].isEnabled })
            app.typeKey(.escape, modifierFlags: [])
        }
        func restoreLibraryWindow() {
            app.activate()
            let item = app.menuBars.menuBarItems["Window"]
            item.click()
            // The window title becomes the recording's title after Stop.
            let windows = item.menus.firstMatch.menuItems.matching(identifier: "makeKeyAndOrderFront:")
            XCTAssertEqual(windows.count, 1)
            windows.firstMatch.click()
            XCTAssertTrue(wait {
                app.windows.matching(NSPredicate(format: "identifier BEGINSWITH %@", "library-AppWindow-"))
                    .firstMatch.isHittable
            })
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
                let progress: [String: Any] = ["caseId": "FUI03", "status": "partial-until-native-verdict",
                    "fixtureTitle": title, "uptime": times, "captureRequested": captureRequested,
                    "stopRequested": stopRequested, "shutdownAcknowledged": shutdownAcknowledged,
                    "exportRequested": exportRequested, "exportAcknowledged": exportAcknowledged,
                    "quitRequested": quitRequested, "quitAcknowledged": quitAcknowledged]
                if let bytes = try? JSONSerialization.data(withJSONObject: progress, options: [.sortedKeys, .prettyPrinted]) {
                    let attachment = XCTAttachment(data: bytes, uniformTypeIdentifier: "public.json")
                    attachment.name = "capture-progress"; attachment.lifetime = .keepAlways; self.add(attachment)
                }
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
        let library = app.windows.matching(NSPredicate(format: "identifier BEGINSWITH %@", "library-AppWindow-")).firstMatch
        library.buttons["_XCUI:MinimizeWindow"].click()
        XCTAssertTrue(wait { libraryHidden() })
        // Keep the fixture unobscured and avoid Expose's transformed thumbnails.
        // This foreground command opens the picker without restoring the library.
        let recordingItem = app.menuBars.menuBarItems["Recording"]
        recordingItem.click()
        recordingItem.menus.firstMatch.menuItems["Choose Display or Window…"].click()
        let picker = system.dialogs["Shared Content Picker Controls"]
        XCTAssertTrue(picker.buttons["Show All Windows"].waitForExistence(timeout: 15))
        XCTAssertTrue(libraryHidden())
        record("01-picker-open", picker: true)
        let frame = fixture.windows[title].frame
        XCTAssertGreaterThan(frame.width, 0); XCTAssertGreaterThan(frame.height, 0)
        let groups = picker.groups.allElementsBoundByIndex
        XCTAssertLessThanOrEqual(groups.count, 8)
        let ownedChoice = groups.filter { element in
            let actual = element.frame
            return abs(actual.minX - frame.minX) <= 0.5 && abs(actual.minY - frame.minY) <= 0.5
                && abs(actual.width - frame.width) <= 0.5 && abs(actual.height - frame.height) <= 0.5
        }
        XCTAssertEqual(ownedChoice.count, 1)
        let center = ownedChoice[0].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        center.hover(); interval(1)
        let geometry: [String: Any] = ["fixtureTitle": title, "libraryHidden": true,
            "fixtureFrame": ["x": frame.minX, "y": frame.minY, "width": frame.width, "height": frame.height],
            "matchedPickerGroups": ownedChoice.count, "point": ["x": center.screenPoint.x, "y": center.screenPoint.y]]
        let geometryAttachment = XCTAttachment(data: try JSONSerialization.data(withJSONObject: geometry,
            options: [.sortedKeys, .prettyPrinted]), uniformTypeIdentifier: "public.json")
        geometryAttachment.name = "02-source-geometry"; geometryAttachment.lifetime = .keepAlways; add(geometryAttachment)
        record("02-window-target", picker: true)
        center.click()
        if !wait({ !picker.exists }, seconds: 5) {
            record("03-window-confirmation", picker: true)
            let shareWindow = system.buttons.matching(NSPredicate(format:
                "label BEGINSWITH[c] %@ AND label CONTAINS[c] %@", "Share", "Window"))
            XCTAssertEqual(shareWindow.count, 1)
            shareWindow.firstMatch.click()
        }
        XCTAssertTrue(wait { !picker.exists })
        restoreLibraryWindow()
        // The callback's selected-filter metadata, not geometry alone, is the
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
        app.activate(); quitRequested = true
        app.typeKey("q", modifierFlags: .command)
        XCTAssertTrue(wait { app.state == .notRunning })
        quitAcknowledged = true
        app.launch(); restoreLibraryWindow()
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
