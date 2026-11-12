import AVFoundation
import CryptoKit
import Foundation
import FrameletCore
import ImageIO
import UniformTypeIdentifiers

// Decodes actual compositor output. Never opens Framelet or capture devices.
@main
struct SoftwarePreviewFiles {
    static func need(_ value: Bool, _ reason: String) throws {
        if !value { throw NSError(domain: "FrameletSoftwarePreviewFiles", code: 1,
            userInfo: [NSLocalizedDescriptionKey: reason]) }
    }

    @MainActor
    static func main() async throws {
        try need(CommandLine.arguments.count == 3, "expected existing authored package and new owned output")
        let package = URL(fileURLWithPath: CommandLine.arguments[1])
        let output = URL(fileURLWithPath: CommandLine.arguments[2])
        try need(!FileManager.default.fileExists(atPath: output.path), "output already exists")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: false)
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let original = try decoder.decode(RecordingProject.self,
            from: Data(contentsOf: package.appendingPathComponent("manifest.json")))
        try need(original.status == .ready && original.segments.count == 2 && original.clips.count == 2, "authored project shape")
        let first = original.clips[0].segmentID
        let blue = try XCTlessUnwrap(original.segments.first(where: { $0.id == original.clips[1].segmentID })?.screenPath)
        var frames: [[String: Any]] = [], cases: [[String: Any]] = []

        func rendered(_ project: RecordingProject, at seconds: Double, name: String) async throws -> CGImage {
            let built = try await RecordingCompositionBuilder.build(project: project, packageURL: package)
            let generator = AVAssetImageGenerator(asset: built.asset)
            generator.videoComposition = try SoftwareRecordingCompositor.videoComposition(from: built.videoComposition)
            generator.requestedTimeToleranceBefore = .zero; generator.requestedTimeToleranceAfter = .zero
            defer { generator.cancelAllCGImageGeneration(); withExtendedLifetime(built) {} }
            let result = try await generator.image(at: CMTime(seconds: seconds, preferredTimescale: 600))
            try need(generator.customVideoCompositor is SoftwareRecordingCompositor, "software compositor was not used")
            let image = result.image
            try need(image.width == project.presentation.preset.width && image.height == project.presentation.preset.height,
                     "rendered canvas size: " + name)
            try need(abs(result.actualTime.seconds - seconds) <= 1.0 / 30, "decoded time: " + name)
            let url = output.appendingPathComponent(name + ".png")
            try need(!FileManager.default.fileExists(atPath: url.path), "frame already exists")
            guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
                throw CocoaError(.fileWriteUnknown)
            }
            CGImageDestinationAddImage(destination, image, nil)
            try need(CGImageDestinationFinalize(destination), "PNG finalization")
            let bytes = try Data(contentsOf: url)
            try need(bytes.count <= 2 * 1024 * 1024, "frame size")
            frames.append(["name": name, "seconds": seconds, "actualSeconds": result.actualTime.seconds,
                "width": image.width, "height": image.height, "bytes": bytes.count,
                "sha256": SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()])
            return image
        }

        func sample(_ image: CGImage, _ x: Double, _ y: Double) throws -> [Int] {
            try rgb(image, rect: CGRect(x: x * Double(image.width) - 8, y: y * Double(image.height) - 8, width: 16, height: 16))
        }
        func red(_ value: [Int]) -> Bool { value[0] > value[1] + 80 && value[0] > value[2] + 80 }
        func isBlue(_ value: [Int]) -> Bool { value[2] > value[0] + 80 && value[2] > value[1] + 80 }
        func background(_ value: [Int], _ colour: CanvasBackground) -> Bool {
            let c = colour.rgb
            return zip(value, [c.0, c.1, c.2].map { Int(($0 * 255).rounded()) }).allSatisfy { abs($0 - $1) <= 18 }
        }

        let firstFrame = try await rendered(original, at: 3, name: "01-recording-red")
        let firstRGB = try sample(firstFrame, 0.5, 0.6), header = try sample(firstFrame, 0.5, 0.11)
        let firstMatte = try sample(firstFrame, 0.01, 0.01)
        try need(red(firstRGB) && header.allSatisfy { $0 > 170 }
            && background(firstMatte, .midnight), "red, upright header or matte")
        cases.append(["name": "ordered-red-upright-matte", "centerRGB": firstRGB, "headerRGB": header])
        let secondFrame = try await rendered(original, at: 15, name: "02-recording-blue")
        let secondRGB = try sample(secondFrame, 0.5, 0.6)
        try need(isBlue(secondRGB), "second take not blue")
        cases.append(["name": "ordered-blue-boundary", "centerRGB": secondRGB])

        var square = original; square.clips.reverse()
        square.presentation.preset = .square; square.presentation.background = .sand
        let squareFrame = try await rendered(square, at: 3, name: "03-square-sand")
        let squareRGB = try sample(squareFrame, 0.5, 0.6)
        let squareMatte = try sample(squareFrame, 0.01, 0.01)
        try need(isBlue(squareRGB) && background(squareMatte, .sand), "square order or Sand matte")
        cases.append(["name": "reordered-square-sand", "centerRGB": squareRGB])

        var pip = original
        let index = try XCTlessUnwrap(pip.segments.firstIndex(where: { $0.id == first }))
        pip.segments[index].cameraPath = blue; pip.segments[index].cameraOffsetSeconds = 0
        pip.presentation.layout = .pictureInPicture; pip.presentation.cameraMirrored = false
        let pipFrame = try await rendered(pip, at: 3, name: "04-camera-pip")
        let camera = try XCTlessUnwrap(pip.presentation.cameraRect)
        let cameraRGB = try sample(pipFrame, camera.x + camera.width / 2, camera.y + camera.height * 0.7)
        let pipScreen = try sample(pipFrame, 0.5, 0.6)
        let pipOutside = try sample(pipFrame, camera.x - 0.02, camera.y + camera.height * 0.7)
        try need(isBlue(cameraRGB) && red(pipScreen) && red(pipOutside), "PiP position/crop escaped its rectangle")
        cases.append(["name": "camera-pip-position-crop", "cameraRGB": cameraRGB])

        var gap = pip; gap.presentation.layout = .sideBySide
        gap.segments[index].cameraOffsetSeconds = 4
        let gapRect = try XCTlessUnwrap(gap.presentation.cameraRect)
        let before = try await rendered(gap, at: 2, name: "05-camera-gap")
        let after = try await rendered(gap, at: 6, name: "06-camera-overlap")
        let beforeRGB = try sample(before, gapRect.x + gapRect.width / 2, 0.6)
        let afterRGB = try sample(after, gapRect.x + gapRect.width / 2, 0.6)
        let sideScreen = try sample(after, 0.3, 0.6)
        try need(background(beforeRGB, .midnight) && isBlue(afterRGB) && red(sideScreen), "side-by-side camera gap/overlap")
        cases.append(["name": "camera-side-by-side-gap", "gapRGB": beforeRGB, "overlapRGB": afterRGB])

        var portrait = pip
        portrait.presentation.preset = .portrait; portrait.presentation.cameraCorner = .topLeft
        portrait.presentation.cameraScale = 0.35
        let unmirrored = try await rendered(portrait, at: 3, name: "07-portrait-camera")
        portrait.presentation.cameraMirrored = true
        let mirrored = try await rendered(portrait, at: 3, name: "08-portrait-mirrored")
        let mirrorRect = try XCTlessUnwrap(portrait.presentation.cameraRect)
        let bounds = CGRect(x: mirrorRect.x * 1080, y: mirrorRect.y * 1920,
            width: mirrorRect.width * 1080, height: mirrorRect.height * 1920)
        let mirrorError = try compareMirror(unmirrored, mirrored, rectangle: bounds)
        try need(mirrorError.mirroredMean < 12 && mirrorError.changedPixels > 0.003,
                 "camera mirror did not reverse actual authored header details")
        cases.append(["name": "portrait-camera-mirror", "mirroredMeanError": mirrorError.mirroredMean,
            "changedPixelFraction": mirrorError.changedPixels])

        let report: [String: Any] = ["kind": "framelet-compatible-preview-files", "verified": true,
            "caseCount": cases.count, "frameCount": frames.count, "cases": cases, "frames": frames,
            "applicationLaunched": false, "captureOrExportRequested": false, "originalsModified": false]
        print(String(data: try JSONSerialization.data(withJSONObject: report, options: .sortedKeys), encoding: .utf8)!)
    }

    static func XCTlessUnwrap<T>(_ value: T?) throws -> T {
        guard let value else { throw CocoaError(.fileReadCorruptFile) }
        return value
    }

    static func pixels(_ image: CGImage, width: Int, height: Int) throws -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let rendered = bytes.withUnsafeMutableBytes { data -> Bool in
            guard let context = CGContext(data: data.baseAddress, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height))); return true
        }
        try need(rendered, "pixel decode")
        return bytes
    }

    static func rgb(_ image: CGImage, rect: CGRect) throws -> [Int] {
        guard let crop = image.cropping(to: rect) else { throw CocoaError(.coderReadCorrupt) }
        let values = try pixels(crop, width: 16, height: 16)
        return (0..<3).map { channel in
            stride(from: channel, to: values.count, by: 4).map { Int(values[$0]) }.sorted()[128]
        }
    }

    static func compareMirror(_ first: CGImage, _ second: CGImage, rectangle: CGRect) throws -> (mirroredMean: Double, changedPixels: Double) {
        guard let a = first.cropping(to: rectangle), let b = second.cropping(to: rectangle) else { throw CocoaError(.coderReadCorrupt) }
        let width = 192, height = 144
        let left = try pixels(a, width: width, height: height), right = try pixels(b, width: width, height: height)
        var error = 0, changed = 0
        for y in 0..<height {
            for x in 0..<width {
                let i = (y * width + x) * 4, reflected = (y * width + width - 1 - x) * 4
                let difference = (0..<3).map { abs(Int(left[i + $0]) - Int(right[i + $0])) }.max()!
                if difference > 20 { changed += 1 }
                for channel in 0..<3 { error += abs(Int(left[i + channel]) - Int(right[reflected + channel])) }
            }
        }
        return (Double(error) / Double(width * height * 3), Double(changed) / Double(width * height))
    }
}
