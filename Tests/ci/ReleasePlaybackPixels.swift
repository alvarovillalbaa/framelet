// Decode original XCTest PNGs outside the UI runner; no player/capture APIs.
import CoreGraphics
import CryptoKit
import Foundation
import ImageIO

@main
struct ReleasePlaybackPixels {
    static func need(_ value: Bool, _ reason: String) throws {
        if !value { throw NSError(domain: "FrameletReleasePlaybackPixels", code: 1,
            userInfo: [NSLocalizedDescriptionKey: reason]) }
    }
    static func read(_ path: String, maximum: Int) throws -> Data {
        let url = URL(fileURLWithPath: path)
        try need(url.standardizedFileURL.path == url.resolvingSymlinksInPath().path, "unsafe input path")
        let info = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
        try need(info.isRegularFile == true && info.isSymbolicLink != true
            && (info.fileSize ?? Int.max) <= maximum, "input identity/size")
        return try Data(contentsOf: url)
    }
    static func sha(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
    static func rectangle(_ value: Any?) throws -> CGRect {
        guard let row = value as? [String: Double], let x = row["x"], let y = row["y"],
              let width = row["width"], let height = row["height"],
              [x, y, width, height].allSatisfy(\.isFinite), width > 0, height > 0 else {
            throw NSError(domain: "FrameletReleasePlaybackPixels", code: 2)
        }
        return CGRect(x: x, y: y, width: width, height: height)
    }
    static func main() throws {
        try need(CommandLine.arguments.count == 2, "expected one owned pixel config")
        let config = try JSONSerialization.jsonObject(with: read(CommandLine.arguments[1], maximum: 65536)) as! [String: Any]
        let raw = try read(config["observations"] as! String, maximum: 65536)
        let observed = try JSONSerialization.jsonObject(with: raw) as! [String: Any]
        try need(observed["caseId"] as? String == "FUI04" && observed["status"] as? String == "passed",
            "native observations missing")
        let phases = observed["phases"] as! [[String: Any]]
        let images = config["images"] as! [String: [String: String]]
        let expected = [("01-initial-paused", "none"), ("02-recording-red", "red"),
            ("03-boundary-blue", "blue"), ("04-seek-red", "red"), ("05-seek-blue", "blue"),
            ("06-selected-blue", "blue"), ("07-selected-red", "red"), ("08-ended-blue", "blue"),
            ("09-replayed-red", "red"), ("10-reopened-red", "red")]
        try need(phases.count == expected.count && Set(images.keys) == Set(expected.map(\.0)), "phase/image identity")
        var results: [[String: Any]] = []
        for (phase, identity) in zip(phases, expected) {
            try need(phase["name"] as? String == identity.0 && phase["expectedColour"] as? String == identity.1,
                "unexpected native phase")
            let imageInfo = images[identity.0]!
            let png = try read(imageInfo["path"]!, maximum: 4 * 1024 * 1024)
            try need(sha(png) == imageInfo["sha256"], "original screenshot changed")
            guard let source = CGImageSourceCreateWithData(png as CFData, nil),
                  CGImageSourceGetCount(source) == 1,
                  let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
                throw NSError(domain: "FrameletReleasePlaybackPixels", code: 3)
            }
            let display = try rectangle(phase["displayBounds"])
            let window = try rectangle(phase["windowFrame"])
            let scope = try rectangle(phase["scopeFrame"])
            let button = try rectangle(phase["buttonFrame"])
            let clock = try rectangle(phase["clockFrame"])
            let point = phase["samplePoint"] as! [String: Double]
            let x = point["x"]!, y = point["y"]!
            try need(display.origin == .zero && display.contains(window) && window.contains(scope)
                && window.contains(button) && window.contains(clock), "preview anchors not fully visible")
            try need(abs(x - (button.minX + clock.maxX) / 2) < 0.01
                && abs(y - (scope.maxY + button.minY) / 2) < 0.01
                && y > scope.maxY + 80 && y < button.minY - 80,
                "sample not inside observed preview bracket")
            let scale = CGFloat(image.width) / display.width
            try need(scale >= 1 && scale <= 3 && abs(CGFloat(image.height) - display.height * scale) < 1,
                "screenshot/display scale mismatch")
            let sample = CGRect(x: CGFloat(x) * scale - 16, y: CGFloat(y) * scale - 16, width: 32, height: 32)
            guard let crop = image.cropping(to: sample) else {
                throw NSError(domain: "FrameletReleasePlaybackPixels", code: 4)
            }
            var pixels = [UInt8](repeating: 0, count: 32 * 32 * 4)
            let rendered = pixels.withUnsafeMutableBytes { buffer -> Bool in
                guard let context = CGContext(data: buffer.baseAddress, width: 32, height: 32, bitsPerComponent: 8,
                    bytesPerRow: 128, space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else { return false }
                context.draw(crop, in: CGRect(x: 0, y: 0, width: 32, height: 32)); return true
            }
            try need(rendered, "cannot decode screenshot pixels")
            let rgb = (0..<3).map { channel in
                stride(from: channel, to: pixels.count, by: 4).map { Int(pixels[$0]) }.sorted()[512]
            }
            if identity.1 == "red" { try need(rgb[0] > rgb[1] + 80 && rgb[0] > rgb[2] + 80, "red preview absent: " + identity.0) }
            if identity.1 == "blue" { try need(rgb[2] > rgb[0] + 80 && rgb[2] > rgb[1] + 80, "blue preview absent: " + identity.0) }
            results.append(["phase": identity.0, "expectedColour": identity.1, "medianRGB": rgb,
                "pngSHA256": sha(png), "nativeTimeText": phase["timeText"]!, "scale": scale])
        }
        let result: [String: Any] = ["kind": "framelet-release-playback-pixels", "verified": true,
            "pixelPhasesVerified": 9, "initialPausedPhaseColourNotRequired": true,
            "observationsSHA256": sha(raw), "phases": results,
            "captureOrPlayerAPIsUsed": false, "originalScreenshotsModified": false]
        print(String(data: try JSONSerialization.data(withJSONObject: result, options: .sortedKeys), encoding: .utf8)!)
    }
}
