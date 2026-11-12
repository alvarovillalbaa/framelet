import AVFoundation
import CryptoKit
import FrameletCore
import XCTest

final class FrameletAcceptance: XCTestCase {
    @MainActor
    func testFUI01EditReopenAndExportNativeRecording() async throws {
        continueAfterFailure = false
        let configURL = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "FixtureConfig", withExtension: "json"))
        let config = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: configURL)) as? [String: String])
        let root = URL(fileURLWithPath: try XCTUnwrap(config["root"]), isDirectory: true)
        // The XCTest runner has its own container. Use only the controller's
        // admitted app-library path and nonce, without changing either app's rights.
        let library = URL(fileURLWithPath: try XCTUnwrap(config["library"]), isDirectory: true)
        XCTAssertEqual(library.lastPathComponent, "Framelet")
        XCTAssertEqual(library.deletingLastPathComponent().lastPathComponent, "Application Support")
        XCTAssertEqual(try String(contentsOf: library.appendingPathComponent(".acceptance-owner"), encoding: .utf8), config["nonce"])
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: library.path).sorted() == [".acceptance-owner"])
        let recordingID = UUID(), redID = UUID(), blueID = UUID()
        let package = library.appendingPathComponent("Recordings/\(recordingID.uuidString).framelet", isDirectory: true)
        let mediaFolder = package.appendingPathComponent("segments", isDirectory: true)
        try FileManager.default.createDirectory(at: mediaFolder, withIntermediateDirectories: true)
        let redPath = "segments/\(redID.uuidString)-screen.mp4", bluePath = "segments/\(blueID.uuidString)-screen.mp4"
        let redURL = package.appendingPathComponent(redPath), blueURL = package.appendingPathComponent(bluePath)
        try await AuthoredVideo.write(to: redURL, rgb: (230, 20, 20))
        try await AuthoredVideo.write(to: blueURL, rgb: (20, 20, 230))
        let originals = try [redURL, blueURL].map { try Data(contentsOf: $0) }
        var project = RecordingProject(id: recordingID, title: "Authored UI recording")
        project.status = .ready
        project.segments = [RecordingSegment(id: redID, screenPath: redPath, durationSeconds: 1.2),
                            RecordingSegment(id: blueID, screenPath: bluePath, durationSeconds: 1.2)]
        project.clips = [RecordingClip(segmentID: redID, trimStartSeconds: 0.1, trimEndSeconds: 0.7),
                         RecordingClip(segmentID: blueID, trimStartSeconds: 0.2, trimEndSeconds: 1.0)]
        try validateRecording(project)
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        let manifestURL = package.appendingPathComponent("manifest.json")
        try encoder.encode(project).write(to: manifestURL, options: .withoutOverwriting)
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        func manifest() throws -> RecordingProject { try decoder.decode(RecordingProject.self, from: Data(contentsOf: manifestURL)) }
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
                app.scrollViews.firstMatch.scroll(byDeltaX: 0, deltaY: -250)
            }
            XCTAssertTrue(element.isHittable)
        }
        func replace(_ field: XCUIElement, with value: String) {
            show(field); field.click(); app.typeKey("a", modifierFlags: .command); app.typeText(value)
        }
        defer {
            if app.state == .runningForeground { record("diagnostic-final") }
            app.terminate()
        }
        app.launch()
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 20))
        XCTAssertTrue(app.staticTexts[project.title].firstMatch.waitForExistence(timeout: 15))
        let play = app.buttons["Play Recording"]
        wait { play.exists && play.isEnabled }
        XCTAssertFalse(app.staticTexts["Recording unavailable"].exists)
        record("01-library-preview")

        app.menuButtons["Recording Actions"].click()
        app.menuItems["Rename…"].click()
        replace(app.textFields["Recording title"], with: "Authored edited recording")
        app.buttons["Save"].click()
        wait { (try? manifest().title) == "Authored edited recording" }
        replace(app.textFields["Start (seconds)"], with: "0.2")
        replace(app.textFields["End (seconds)"], with: "0.6")
        app.buttons["Apply Trim"].click()
        wait { abs(((try? manifest().clips[0].durationSeconds) ?? 0) - 0.4) < 0.0001 }
        app.buttons["Duplicate clip 1"].click()
        wait { (try? manifest().clips.count) == 3 }
        app.buttons["Move clip 2 later"].click()
        wait { (try? manifest().clips.map(\.segmentID)) == [redID, blueID, redID] }
        app.buttons["Remove clip 3 from edit"].click()
        wait { (try? manifest().clips.count) == 2 }
        app.buttons["Move clip 2 earlier"].click()
        wait { (try? manifest().clips.map(\.segmentID)) == [blueID, redID] }
        record("02-edited-clips")

        let disclosure = app.disclosureTriangles["Canvas and camera layout"]
        show(disclosure); disclosure.click()
        let canvas = app.popUpButtons["Canvas"]
        show(canvas); canvas.click(); app.menuItems["Square"].click()
        app.popUpButtons["Background"].click(); app.menuItems["Sand"].click()
        let applyCanvas = app.buttons["Apply Canvas"]
        show(applyCanvas); XCTAssertTrue(applyCanvas.isEnabled); applyCanvas.click()
        wait { (try? manifest().presentation.preset) == .square && (try? manifest().presentation.background) == .sand }
        let edited = try manifest()
        XCTAssertEqual(edited.durationSeconds, 1.2, accuracy: 0.0001)
        XCTAssertEqual(edited.segments, project.segments)

        let exportButton = app.buttons["Export…"]
        show(exportButton); XCTAssertTrue(exportButton.isEnabled); exportButton.click()
        app.typeKey("g", modifierFlags: [.command, .shift]); app.typeText(root.path); app.typeKey(.return, modifierFlags: [])
        XCTAssertTrue(app.dialogs.buttons["Save"].waitForExistence(timeout: 15))
        let filename = app.dialogs.textFields.firstMatch
        XCTAssertTrue(filename.waitForExistence(timeout: 15))
        replace(filename, with: "authored-ui-export.mp4")
        app.dialogs.buttons["Save"].click()
        let output = root.appendingPathComponent("authored-ui-export.mp4")
        wait({ FileManager.default.fileExists(atPath: output.path) }, timeout: 30)
        XCTAssertTrue(app.staticTexts["Most recent export: authored-ui-export.mp4"].waitForExistence(timeout: 15))
        record("03-native-export")
        let asset = AVURLAsset(url: output)
        let duration = try await asset.load(.duration)
        XCTAssertEqual(duration.seconds, 1.2, accuracy: 1.0 / 30)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        let track = try XCTUnwrap(tracks.first)
        let size = try await track.load(.naturalSize)
        XCTAssertEqual(size.width, 1080); XCTAssertEqual(size.height, 1080)
        let first = try await AuthoredVideo.sample(asset: asset, seconds: 0.2)
        let second = try await AuthoredVideo.sample(asset: asset, seconds: 1.0)
        XCTAssertGreaterThan(first[2], first[0] + 80); XCTAssertGreaterThan(first[2], first[1] + 80)
        XCTAssertGreaterThan(second[0], second[2] + 80); XCTAssertGreaterThan(second[0], second[1] + 80)
        for (url, bytes) in zip([redURL, blueURL], originals) { XCTAssertEqual(try Data(contentsOf: url), bytes) }
        XCTAssertFalse(try FileManager.default.contentsOfDirectory(atPath: root.path).contains { $0.hasPrefix(".framelet-export-") })
        app.terminate(); app.launch()
        XCTAssertTrue(app.staticTexts["Authored edited recording"].firstMatch.waitForExistence(timeout: 20))
        wait { app.buttons["Play Recording"].exists && app.buttons["Play Recording"].isEnabled }
        XCTAssertEqual(try manifest().clips, edited.clips); XCTAssertEqual(try manifest().presentation, edited.presentation)
        for (url, bytes) in zip([redURL, blueURL], originals) { XCTAssertEqual(try Data(contentsOf: url), bytes) }
        record("04-reopened-library")
        let observation: [String: Any] = ["caseId": "FUI01", "status": "passed", "durationSeconds": duration.seconds,
            "width": size.width, "height": size.height, "firstRGB": first, "secondRGB": second,
            "project": String(data: try encoder.encode(edited), encoding: .utf8)!,
            "originalSHA256": originals.map { SHA256.hash(data: $0).map { String(format: "%02x", $0) }.joined() },
            "outputSHA256": SHA256.hash(data: try Data(contentsOf: output)).map { String(format: "%02x", $0) }.joined()]
        let attachment = XCTAttachment(data: try JSONSerialization.data(withJSONObject: observation, options: [.sortedKeys, .prettyPrinted]), uniformTypeIdentifier: "public.json")
        attachment.name = "ui-observations"; attachment.lifetime = .keepAlways; add(attachment)
    }
}

private enum AuthoredVideo {
    @MainActor
    static func write(to url: URL, rgb: (UInt8, UInt8, UInt8)) async throws {
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        defer { if writer.status != .completed { writer.cancelWriting() } }
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: 64, AVVideoHeightKey: 48,
            AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 64000, AVVideoMaxKeyFrameIntervalKey: 1]])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: 64, kCVPixelBufferHeightKey as String: 48])
        XCTAssertTrue(writer.canAdd(input)); writer.add(input); XCTAssertTrue(writer.startWriting()); writer.startSession(atSourceTime: .zero)
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(10))
        for frame in 0..<12 {
            while !input.isReadyForMoreMediaData {
                guard clock.now < deadline else { throw NSError(domain: "fixture-timeout", code: 1) }
                try await Task.sleep(for: .milliseconds(5))
            }
            var buffer: CVPixelBuffer?
            XCTAssertEqual(CVPixelBufferCreate(kCFAllocatorDefault, 64, 48, kCVPixelFormatType_32BGRA, nil, &buffer), kCVReturnSuccess)
            let pixel = try XCTUnwrap(buffer)
            XCTAssertEqual(CVPixelBufferLockBaseAddress(pixel, []), kCVReturnSuccess)
            let base = try XCTUnwrap(CVPixelBufferGetBaseAddress(pixel))
            memset(base, 0, CVPixelBufferGetDataSize(pixel))
            for row in 0..<48 {
                let values = base.advanced(by: row * CVPixelBufferGetBytesPerRow(pixel)).assumingMemoryBound(to: UInt8.self)
                for column in 0..<64 { values[column * 4] = rgb.2; values[column * 4 + 1] = rgb.1; values[column * 4 + 2] = rgb.0; values[column * 4 + 3] = 255 }
            }
            CVPixelBufferUnlockBaseAddress(pixel, [])
            XCTAssertTrue(adaptor.append(pixel, withPresentationTime: CMTime(value: Int64(frame), timescale: 10)))
        }
        input.markAsFinished(); writer.endSession(atSourceTime: CMTime(value: 12, timescale: 10)); writer.finishWriting { }
        while writer.status == .writing {
            guard clock.now < deadline else { throw NSError(domain: "fixture-timeout", code: 2) }
            try await Task.sleep(for: .milliseconds(5))
        }
        XCTAssertEqual(writer.status, .completed)
    }

    static func sample(asset: AVAsset, seconds: Double) async throws -> [Int] {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero; generator.requestedTimeToleranceAfter = .zero
        let image = try await generator.image(at: CMTime(seconds: seconds, preferredTimescale: 600)).image
        let crop = try XCTUnwrap(image.cropping(to: CGRect(x: CGFloat(image.width) / 3, y: CGFloat(image.height) / 3,
            width: CGFloat(image.width) / 3, height: CGFloat(image.height) / 3)))
        var pixel = [UInt8](repeating: 0, count: 4)
        let rendered = pixel.withUnsafeMutableBytes { bytes -> Bool in
            guard let context = CGContext(data: bytes.baseAddress, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else { return false }
            context.draw(crop, in: CGRect(x: 0, y: 0, width: 1, height: 1)); return true
        }
        XCTAssertTrue(rendered); return pixel.prefix(3).map(Int.init)
    }
}
