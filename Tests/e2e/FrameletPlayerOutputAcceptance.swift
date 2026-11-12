import Foundation
import XCTest

final class FrameletPlayerOutputAcceptance: XCTestCase {
    @MainActor
    func testFUI04OInspectPlayerOutputAndPresentation() throws {
        continueAfterFailure = false
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "FixtureConfig", withExtension: "json"))
        let config = try JSONDecoder().decode([String: String].self, from: Data(contentsOf: url))
        let probe = XCUIApplication(url: URL(fileURLWithPath: try XCTUnwrap(config["renderingProbeApp"])))
        var normalQuit = false
        addTeardownBlock {
            await MainActor.run {
                if probe.state != .notRunning { probe.terminate() }
                let data: [String: Any] = ["caseId": "FUI04O", "safeToTerminate": true,
                    "productNeverLaunched": true, "readOnlyProbeNormalQuit": normalQuit,
                    "captureOrExportRequested": false, "forcedWriterTermination": false]
                if let bytes = try? JSONSerialization.data(withJSONObject: data, options: [.sortedKeys]) {
                    let attachment = XCTAttachment(data: bytes, uniformTypeIdentifier: "public.json")
                    attachment.name = "playback-shutdown"; attachment.lifetime = .keepAlways; self.add(attachment)
                }
            }
        }
        probe.launchArguments = [try XCTUnwrap(config["renderingProbeConfig"])]; probe.launch()
        for phase in ["red", "blue"] {
            if phase == "blue" { probe.buttons["Show blue"].click() }
            XCTAssertTrue(probe.staticTexts["Player output probe " + phase + " ready"].firstMatch.waitForExistence(timeout: 35))
            XCTAssertTrue(probe.windows.firstMatch.isHittable)
            RunLoop.current.run(until: Date().addingTimeInterval(0.8))
            let tree = XCTAttachment(string: probe.debugDescription)
            tree.name = "diagnostic-output-" + phase + ".accessibility"; tree.lifetime = .keepAlways; add(tree)
            let image = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            image.name = "diagnostic-output-" + phase; image.lifetime = .keepAlways; add(image)
            let output = URL(fileURLWithPath: try XCTUnwrap(config["renderingProbeReport"]))
            let bytes = try Data(contentsOf: output.appendingPathComponent(phase + ".json"))
            let data = XCTAttachment(data: bytes, uniformTypeIdentifier: "public.json")
            data.name = "diagnostic-output-" + phase; data.lifetime = .keepAlways; add(data)
        }
        probe.typeKey("q", modifierFlags: .command)
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in probe.state == .notRunning }, object: nil)], timeout: 10), .completed)
        normalQuit = true
    }
}
