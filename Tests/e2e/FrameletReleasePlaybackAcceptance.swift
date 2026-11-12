import CoreGraphics
import Foundation
import XCTest

// Native UI only. The host binds the released bundle, seeds authored originals,
// verifies rendered screenshots and proves that no library bytes changed.
final class FrameletReleasePlaybackAcceptance: XCTestCase {
    @MainActor
    func testFUI04PlayRealCapturedTakesInReleasedApp() throws {
        continueAfterFailure = false
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "FixtureConfig", withExtension: "json"))
        let config = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: String])
        let title = try XCTUnwrap(config["title"])
        let firstDuration = try XCTUnwrap(Double(config["firstDuration"] ?? ""))
        let totalDuration = try XCTUnwrap(Double(config["totalDuration"] ?? ""))
        let app = XCUIApplication(bundleIdentifier: "com.alvarovillalbaa.Framelet")
        var phases: [[String: Any]] = []
        var normalQuitAtEnd = false
        func interval(_ seconds: Double) {
            let end = ProcessInfo.processInfo.systemUptime + seconds
            while ProcessInfo.processInfo.systemUptime < end {
                RunLoop.current.run(until: Date().addingTimeInterval(0.1))
            }
        }
        func wait(_ condition: @escaping () -> Bool, seconds: Double = 20) {
            XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
                predicate: NSPredicate { _, _ in condition() }, object: nil)], timeout: seconds), .completed)
        }
        func readyWithoutCapture() -> Bool {
            app.staticTexts["Ready to record"].firstMatch.exists
                && app.buttons["Choose Source…"].firstMatch.isEnabled
                && app.buttons["Start"].exists && !app.buttons["Start"].isEnabled
        }
        func timeElement() -> XCUIElement {
            let pattern = "^[0-9]+:[0-9]{2} / [0-9]+:[0-9]{2}$"
            let query = app.staticTexts.matching(NSPredicate(format:
                "value MATCHES %@ OR label MATCHES %@", pattern, pattern))
            XCTAssertEqual(query.count, 1)
            return query.firstMatch
        }
        func timeText() -> String {
            let element = timeElement()
            return (element.value as? String) ?? element.label
        }
        func seconds(_ text: Substring) -> Double {
            let parts = text.split(separator: ":").compactMap { Double($0) }
            return parts.count == 2 ? parts[0] * 60 + parts[1] : -.infinity
        }
        func position() -> Double { seconds(timeText().split(separator: "/")[0].trimmingCharacters(in: .whitespaces)[...]) }
        func duration() -> Double { seconds(timeText().split(separator: "/")[1].trimmingCharacters(in: .whitespaces)[...]) }
        func slider(_ clip: Bool = false) -> XCUIElement {
            app.sliders[clip ? "Clip playback position" : "Recording playback position"]
        }
        func playButton(_ clip: Bool = false) -> XCUIElement { app.buttons[clip ? "Play Clip" : "Play Recording"] }
        func visible(_ element: XCUIElement) -> Bool { element.exists && element.isHittable }
        func showPreview() {
            let scroll = app.scrollViews.containing(.button, identifier: "Export…").firstMatch
            let scope = app.radioGroups["Preview scope"]
            let recordingControl = scope.radioButtons["Recording"]
            for _ in 0..<8 {
                if recordingControl.exists
                    && (visible(app.buttons["Play Recording"]) || visible(app.buttons["Play Clip"])
                        || visible(app.buttons["Pause Playback"]))
                    && scroll.frame.contains(scope.frame)
                    && scroll.frame.contains(timeElement().frame) { break }
                scroll.scroll(byDeltaX: 0, deltaY: 250)
            }
            XCTAssertTrue(recordingControl.exists)
            XCTAssertTrue(visible(app.buttons["Play Recording"]) || visible(app.buttons["Play Clip"])
                || visible(app.buttons["Pause Playback"]))
            XCTAssertTrue(scroll.frame.contains(scope.frame))
            XCTAssertTrue(scroll.frame.contains(timeElement().frame))
        }
        func showClip(_ number: Int) -> XCUIElement {
            let element = app.buttons["Select clip \(number)"]
            XCTAssertTrue(element.waitForExistence(timeout: 15))
            for _ in 0..<8 {
                if element.isHittable { break }
                app.scrollViews.containing(.button, identifier: "Export…").firstMatch.scroll(byDeltaX: 0, deltaY: -250)
            }
            XCTAssertTrue(element.isHittable)
            return element
        }
        func paused(_ clip: Bool = false) {
            if app.buttons["Pause Playback"].exists { app.buttons["Pause Playback"].click() }
            wait { playButton(clip).exists && playButton(clip).isEnabled && !app.buttons["Pause Playback"].exists }
            interval(0.8)
        }
        func playTo(_ minimum: Double, clip: Bool = false) {
            XCTAssertTrue(playButton(clip).isHittable)
            playButton(clip).click()
            wait { app.buttons["Pause Playback"].exists && position() >= minimum }
            paused(clip)
        }
        func seek(_ fraction: Double) {
            XCTAssertTrue(slider().isHittable)
            slider().adjust(toNormalizedSliderPosition: CGFloat(fraction))
            wait { abs(position() - totalDuration * fraction) <= 1.5 }
            XCTAssertFalse(app.buttons["Pause Playback"].exists)
            interval(1)
        }
        func rectangle(_ rect: CGRect) -> [String: Double] {
            ["x": rect.minX, "y": rect.minY, "width": rect.width, "height": rect.height]
        }
        func record(_ name: String, colour: String = "none", clip: Bool = false) {
            showPreview()
            XCTAssertTrue(readyWithoutCapture())
            XCTAssertFalse(app.buttons["Reload Preview"].exists)
            let tree = app.debugDescription
            let hierarchy = XCTAttachment(string: tree)
            hierarchy.name = name + ".accessibility"; hierarchy.lifetime = .keepAlways; add(hierarchy)
            let scope = app.radioGroups["Preview scope"].frame
            let button = playButton(clip).frame
            let clock = timeElement().frame
            let window = app.windows.matching(NSPredicate(format:
                "identifier BEGINSWITH %@", "library-AppWindow-")).firstMatch.frame
            let display = CGDisplayBounds(CGMainDisplayID())
            // Both anchors bracket the actual visible preview. This is a
            // window-relative observation, not a fixed screenshot coordinate.
            let point = CGPoint(x: (button.minX + clock.maxX) / 2,
                                y: (scope.maxY + button.minY) / 2)
            XCTAssertTrue(window.contains(point)); XCTAssertTrue(display.contains(point))
            XCTAssertGreaterThan(button.minY - scope.maxY, 190)
            let pidPattern = try! NSRegularExpression(pattern: "pid: ([0-9]+)")
            let match = pidPattern.firstMatch(in: tree, range: NSRange(tree.startIndex..., in: tree))
            XCTAssertNotNil(match)
            let pidRange = Range(match!.range(at: 1), in: tree)!
            phases.append(["name": name, "expectedColour": colour, "processID": Int(tree[pidRange])!,
                "displayBounds": rectangle(display), "windowFrame": rectangle(window),
                "scopeFrame": rectangle(scope), "buttonFrame": rectangle(button), "clockFrame": rectangle(clock),
                "samplePoint": ["x": point.x, "y": point.y], "timeText": timeText(),
                "normalizedPosition": slider(clip).normalizedSliderPosition,
                "uptime": ProcessInfo.processInfo.systemUptime])
            let image = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            image.name = name; image.lifetime = .keepAlways; add(image)
        }
        func launchReady() {
            app.launch()
            XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 20))
            app.activate()
            let item = app.menuBars.menuBarItems["Window"]; item.click()
            let windows = item.menus.firstMatch.menuItems.matching(identifier: "makeKeyAndOrderFront:")
            XCTAssertEqual(windows.count, 1); windows.firstMatch.click()
            XCTAssertTrue(app.staticTexts[title].firstMatch.waitForExistence(timeout: 15))
            showPreview()
            wait { playButton().exists && playButton().isEnabled }
            XCTAssertTrue(readyWithoutCapture())
            XCTAssertEqual(duration(), floor(totalDuration))
            XCTAssertEqual(position(), 0)
            XCTAssertFalse(app.buttons["Pause Playback"].exists)
        }
        addTeardownBlock {
            await MainActor.run {
                let safe = app.state == .notRunning || readyWithoutCapture()
                let progress: [String: Any] = ["caseId": "FUI04", "status": "partial-until-native-verdict",
                    "phases": phases, "normalQuitAtEnd": normalQuitAtEnd]
                if let bytes = try? JSONSerialization.data(withJSONObject: progress, options: [.sortedKeys, .prettyPrinted]) {
                    let attachment = XCTAttachment(data: bytes, uniformTypeIdentifier: "public.json")
                    attachment.name = "playback-progress"; attachment.lifetime = .keepAlways; self.add(attachment)
                }
                if app.state != .notRunning {
                    let attachment = XCTAttachment(string: app.debugDescription)
                    attachment.name = "diagnostic-final.accessibility"; attachment.lifetime = .keepAlways; self.add(attachment)
                    let image = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
                    image.name = "diagnostic-final"; image.lifetime = .keepAlways; self.add(image)
                }
                let shutdown: [String: Any] = ["caseId": "FUI04", "safeToTerminate": safe,
                    "noSelectedSourceAndStartDisabled": safe, "captureOrExportRequested": false,
                    "forcedWriterTermination": false]
                if let bytes = try? JSONSerialization.data(withJSONObject: shutdown, options: [.sortedKeys]) {
                    let attachment = XCTAttachment(data: bytes, uniformTypeIdentifier: "public.json")
                    attachment.name = "playback-shutdown"; attachment.lifetime = .keepAlways; self.add(attachment)
                }
                if safe && app.state != .notRunning { app.terminate() }
                // Independent diagnostic only, after the product has stopped.
                // It never substitutes for the ten product phases or their pixels.
                if safe, app.state == .notRunning, let path = config["renderingProbeApp"],
                   let input = config["renderingProbeConfig"], let output = config["renderingProbeReport"] {
                    let probe = XCUIApplication(url: URL(fileURLWithPath: path))
                    probe.launchArguments = [input]
                    probe.launch()
                    let ready = probe.staticTexts["Read-only rendering probe ready"].firstMatch
                    _ = ready.waitForExistence(timeout: 25)
                    let tree = XCTAttachment(string: probe.debugDescription)
                    tree.name = "diagnostic-rendering-probe.accessibility"; tree.lifetime = .keepAlways; self.add(tree)
                    let image = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
                    image.name = "diagnostic-rendering-probe"; image.lifetime = .keepAlways; self.add(image)
                    if let bytes = try? Data(contentsOf: URL(fileURLWithPath: output)) {
                        let data = XCTAttachment(data: bytes, uniformTypeIdentifier: "public.json")
                        data.name = "diagnostic-rendering-probe"; data.lifetime = .keepAlways; self.add(data)
                    }
                    probe.typeKey("q", modifierFlags: .command)
                    if probe.state != .notRunning { probe.terminate() }
                }
            }
        }

        launchReady(); interval(2)
        XCTAssertEqual(position(), 0); record("01-initial-paused")
        playTo(2); XCTAssertLessThan(position(), firstDuration - 1)
        record("02-recording-red", colour: "red")
        let frozen = slider().normalizedSliderPosition
        let frozenTime = timeText(); interval(3)
        XCTAssertEqual(timeText(), frozenTime)
        XCTAssertLessThanOrEqual(abs(slider().normalizedSliderPosition - frozen), 0.015)
        // Resume without seeking and cross the real segment boundary.
        playTo(firstDuration + 2)
        XCTAssertLessThan(position(), totalDuration - 1)
        record("03-boundary-blue", colour: "blue")
        seek(0.2); record("04-seek-red", colour: "red")
        seek(0.7); record("05-seek-blue", colour: "blue")

        showClip(2).click(); showPreview()
        app.radioGroups["Preview scope"].radioButtons["Selected Clip"].click()
        wait { playButton(true).exists && playButton(true).isEnabled }
        XCTAssertEqual(position(), 0); XCTAssertEqual(duration(), floor(totalDuration - firstDuration))
        interval(1); XCTAssertEqual(position(), 0)
        playTo(2, clip: true); record("06-selected-blue", colour: "blue", clip: true)
        showClip(1).click(); showPreview()
        wait { playButton(true).isEnabled && position() == 0 && duration() == floor(firstDuration) }
        interval(1); XCTAssertEqual(position(), 0)
        playTo(2, clip: true); record("07-selected-red", colour: "red", clip: true)

        app.radioGroups["Preview scope"].radioButtons["Recording"].click()
        wait { playButton().exists && playButton().isEnabled && position() == 0 }
        XCTAssertEqual(duration(), floor(totalDuration)); seek(0.92)
        playButton().click()
        wait({ playButton().exists && position() >= floor(totalDuration) }, seconds: 12)
        XCTAssertFalse(app.buttons["Pause Playback"].exists)
        record("08-ended-blue", colour: "blue")
        playTo(2); XCTAssertLessThan(position(), firstDuration - 1)
        record("09-replayed-red", colour: "red")

        app.typeKey("q", modifierFlags: .command); wait { app.state == .notRunning }
        launchReady(); playTo(2); record("10-reopened-red", colour: "red")
        XCTAssertTrue(app.buttons["Select clip 2"].exists)
        XCTAssertFalse(app.buttons["Select clip 3"].exists)
        app.typeKey("q", modifierFlags: .command); wait { app.state == .notRunning }
        normalQuitAtEnd = true
        let observations: [String: Any] = ["caseId": "FUI04", "status": "passed", "phases": phases,
            "pauseFreezesPosition": true, "continuousBoundaryWithoutSeek": true,
            "selectedClipChangesStopAndReload": true, "endedThenReplayFromBeginning": true,
            "normalQuitAtEnd": true, "captureOrExportRequested": false,
            "fileAndPixelVerificationOwner": "host controller"]
        let attachment = XCTAttachment(data: try JSONSerialization.data(withJSONObject: observations,
            options: [.sortedKeys, .prettyPrinted]), uniformTypeIdentifier: "public.json")
        attachment.name = "playback-observations"; attachment.lifetime = .keepAlways; add(attachment)
    }
}

// A separate diagnostic case; the complete FUI04 body above remains unchanged.
final class FrameletCompositionProbeAcceptance: XCTestCase {
    @MainActor
    func testFUI04DInspectAssembledRecording() throws {
        continueAfterFailure = false
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "FixtureConfig", withExtension: "json"))
        let config = try JSONDecoder().decode([String: String].self, from: Data(contentsOf: url))
        let probe = XCUIApplication(url: URL(fileURLWithPath: try XCTUnwrap(config["renderingProbeApp"])))
        var normalQuit = false
        addTeardownBlock {
            await MainActor.run {
                if probe.state != .notRunning { probe.terminate() }
                let data: [String: Any] = ["caseId": "FUI04D", "safeToTerminate": true,
                    "productNeverLaunched": true, "readOnlyProbeNormalQuit": normalQuit,
                    "captureOrExportRequested": false, "forcedWriterTermination": false]
                if let bytes = try? JSONSerialization.data(withJSONObject: data, options: [.sortedKeys]) {
                    let attachment = XCTAttachment(data: bytes, uniformTypeIdentifier: "public.json")
                    attachment.name = "playback-shutdown"; attachment.lifetime = .keepAlways; self.add(attachment)
                }
            }
        }
        probe.launchArguments = [try XCTUnwrap(config["renderingProbeConfig"])]; probe.launch()
        XCTAssertTrue(probe.staticTexts["Read-only composition probe ready"].firstMatch.waitForExistence(timeout: 35))
        let tree = XCTAttachment(string: probe.debugDescription)
        tree.name = "diagnostic-composition-probe.accessibility"; tree.lifetime = .keepAlways; add(tree)
        let image = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        image.name = "diagnostic-composition-probe"; image.lifetime = .keepAlways; add(image)
        let bytes = try Data(contentsOf: URL(fileURLWithPath: try XCTUnwrap(config["renderingProbeReport"])))
        let data = XCTAttachment(data: bytes, uniformTypeIdentifier: "public.json")
        data.name = "diagnostic-composition-probe"; data.lifetime = .keepAlways; add(data)
        probe.typeKey("q", modifierFlags: .command)
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in probe.state == .notRunning }, object: nil)], timeout: 10), .completed)
        normalQuit = true
    }
}
