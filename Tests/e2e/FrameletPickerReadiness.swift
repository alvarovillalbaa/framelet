import AppKit
import Foundation
import XCTest

// Presentation/cancellation only. This probe never selects a source or Start.
// It does not inspect the recorder's library or alter any permission settings.
final class FrameletPickerReadiness: XCTestCase {
    @MainActor
    func testFUI03APresentOwnedWindowPicker() throws {
        continueAfterFailure = false
        let configURL = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "FixtureConfig", withExtension: "json"))
        let config = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: configURL)) as? [String: String])
        let title = "Framelet authored capture " + (try XCTUnwrap(config["nonce"]))
        let app = XCUIApplication(bundleIdentifier: "com.alvarovillalbaa.Framelet")
        let fixture = XCUIApplication(bundleIdentifier: "com.alvarovillalbaa.FrameletAuthoredFixture")
        func attach(_ name: String, application: XCUIApplication) {
            let tree = XCTAttachment(string: application.debugDescription)
            tree.name = name + ".accessibility"; tree.lifetime = .keepAlways; add(tree)
        }
        func screen(_ name: String) {
            let image = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            image.name = name; image.lifetime = .keepAlways; add(image)
        }
        addTeardownBlock {
            await MainActor.run {
                attach("diagnostic-recorder", application: app)
                screen("diagnostic-final")
                // No capture was started in this presentation-only profile.
                app.terminate()
            }
        }
        XCTAssertTrue(fixture.windows[title].waitForExistence(timeout: 15))
        fixture.activate()
        XCTAssertTrue(fixture.buttons["Authored Red"].waitForExistence(timeout: 10))
        fixture.buttons["Authored Red"].click()
        attach("01-authored-fixture", application: fixture); screen("01-authored-fixture")
        app.launch()
        XCTAssertTrue(app.buttons["Choose Source…"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.staticTexts["Ready to record"].firstMatch.exists)
        XCTAssertTrue(app.staticTexts["No display or window selected"].firstMatch.exists)
        XCTAssertFalse(app.buttons["Start"].isEnabled)
        for label in ["System audio", "Default microphone", "Default camera"] {
            let toggle = app.checkBoxes[label]
            XCTAssertTrue(toggle.exists, label)
            XCTAssertEqual((toggle.value as? NSNumber)?.intValue ?? Int(toggle.value as? String ?? ""), 0, label)
        }
        attach("02-recorder-ready", application: app); screen("02-recorder-ready")
        app.buttons["Choose Source…"].click()
        XCTAssertTrue(app.staticTexts["Choose a display or window"].firstMatch.waitForExistence(timeout: 10))
        // Give the system-owned picker a bounded presentation interval.
        let interval = Date().addingTimeInterval(3)
        while Date() < interval { RunLoop.current.run(until: Date().addingTimeInterval(0.1)) }
        attach("03-picker-recorder", application: app)
        let running = NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy != .prohibited && $0.bundleIdentifier != nil && !$0.isTerminated
        }
        XCTAssertLessThanOrEqual(running.count, 16)
        var applications: [[String: Any]] = []
        for (index, process) in running.enumerated() {
            let bundle = try XCTUnwrap(process.bundleIdentifier)
            let application = XCUIApplication(bundleIdentifier: bundle)
            applications.append(["bundleIdentifier": bundle, "pid": process.processIdentifier,
                "activationPolicy": process.activationPolicy.rawValue, "state": application.state.rawValue])
            attach(String(format: "03-system-%02d", index), application: application)
        }
        screen("03-native-picker")
        app.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(app.staticTexts["Ready to record"].firstMatch.waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["No display or window selected"].firstMatch.exists)
        XCTAssertFalse(app.buttons["Start"].isEnabled)
        attach("04-picker-cancelled", application: app); screen("04-picker-cancelled")
        let observed: [String: Any] = ["caseId": "FUI03A", "status": "presentation-cancellation-observed",
            "fixtureTitle": title, "sourceSelected": false, "startClicked": false,
            "capturePerformed": false, "cameraMicrophoneSystemAudioOff": true,
            "readyAfterCancel": true, "runningApplications": applications,
            "scope": "Picker screenshots and AX originals require review; no source-selection or capture proof."]
        let attachment = XCTAttachment(data: try JSONSerialization.data(withJSONObject: observed,
            options: [.sortedKeys, .prettyPrinted]), uniformTypeIdentifier: "public.json")
        attachment.name = "picker-observations"; attachment.lifetime = .keepAlways; add(attachment)
    }
}
