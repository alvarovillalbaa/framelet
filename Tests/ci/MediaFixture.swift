// Host-owned CI fixture preparation/verification. The sandboxed UI runner never
// receives filesystem rights to the app library. This executable is not shipped.
import AVFoundation
import CryptoKit
import Foundation

@main @MainActor
struct MediaFixture {
    static func need(_ value: Bool, _ reason: String) throws {
        if !value { throw NSError(domain: "FrameletFixture", code: 1, userInfo: [NSLocalizedDescriptionKey: reason]) }
    }
    static func digest(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    static func main() async throws {
        try need(CommandLine.arguments.count == 3, "invalid fixture command")
        let mode = CommandLine.arguments[1]
        try need(["prepare", "verify"].contains(mode), "invalid fixture mode")
        let config = try JSONDecoder().decode([String: String].self, from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[2])))
        guard let rootPath = config["root"], let libraryPath = config["library"], let nonce = config["nonce"] else { throw NSError(domain: "FrameletFixture", code: 2) }
        let root = URL(fileURLWithPath: rootPath, isDirectory: true)
        let library = URL(fileURLWithPath: libraryPath, isDirectory: true)
        try need(root.path == root.resolvingSymlinksInPath().path && library.path == library.resolvingSymlinksInPath().path, "fixture path changed")
        try need(try String(contentsOf: root.appendingPathComponent("owner"), encoding: .utf8) == nonce, "root ownership changed")
        try need(try String(contentsOf: library.appendingPathComponent(".acceptance-owner"), encoding: .utf8) == nonce, "library ownership changed")
        let seedURL = root.appendingPathComponent("seed-project.json")
        let hashesURL = root.appendingPathComponent("seed-media-hashes.json")
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601; encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        if mode == "prepare" {
            try need(try FileManager.default.contentsOfDirectory(atPath: library.path) == [".acceptance-owner"], "existing library content")
            var project = RecordingProject(title: "Authored UI recording")
            let red = UUID(), blue = UUID()
            let package = library.appendingPathComponent("Recordings/\(project.id.uuidString).framelet", isDirectory: true)
            try FileManager.default.createDirectory(at: package.appendingPathComponent("segments"), withIntermediateDirectories: true)
            let redPath = "segments/\(red.uuidString)-screen.mp4", bluePath = "segments/\(blue.uuidString)-screen.mp4"
            try await write(to: package.appendingPathComponent(redPath), rgb: (230, 20, 20))
            try await write(to: package.appendingPathComponent(bluePath), rgb: (20, 20, 230))
            project.status = .ready
            project.segments = [RecordingSegment(id: red, screenPath: redPath, durationSeconds: 1.2), RecordingSegment(id: blue, screenPath: bluePath, durationSeconds: 1.2)]
            project.clips = [RecordingClip(segmentID: red, trimStartSeconds: 0.1, trimEndSeconds: 0.7), RecordingClip(segmentID: blue, trimStartSeconds: 0.2, trimEndSeconds: 1.0)]
            try validateRecording(project)
            let data = try encoder.encode(project)
            try data.write(to: package.appendingPathComponent("manifest.json"), options: .withoutOverwriting)
            try data.write(to: seedURL, options: .withoutOverwriting)
            let hashes = try Dictionary(uniqueKeysWithValues: project.segments.map { ($0.screenPath, digest(try Data(contentsOf: package.appendingPathComponent($0.screenPath)))) })
            try encoder.encode(hashes).write(to: hashesURL, options: .withoutOverwriting)
            print(String(data: try JSONSerialization.data(withJSONObject: ["prepared": true, "projectID": project.id.uuidString, "mediaSHA256": hashes], options: .sortedKeys), encoding: .utf8)!)
        } else {
            let seed = try decoder.decode(RecordingProject.self, from: Data(contentsOf: seedURL))
            let package = library.appendingPathComponent("Recordings/\(seed.id.uuidString).framelet", isDirectory: true)
            let project = try decoder.decode(RecordingProject.self, from: Data(contentsOf: package.appendingPathComponent("manifest.json")))
            try validateRecording(project)
            try need(project.id == seed.id && project.title == "Authored edited recording" && project.status == .ready, "saved recording identity/title/status")
            try need(project.segments == seed.segments && project.options == seed.options && project.clips.count == 2, "original segments/options or clip count changed")
            try need(project.clips[0].id == seed.clips[1].id && project.clips[1].id == seed.clips[0].id, "native duplicate/remove/reorder identity")
            try need(project.clips.map(\.segmentID) == [seed.segments[1].id, seed.segments[0].id], "saved clip order")
            try need(abs(project.clips[0].trimStartSeconds - 0.2) < 0.00001 && abs(project.clips[0].trimEndSeconds - 1.0) < 0.00001
                && abs(project.clips[1].trimStartSeconds - 0.2) < 0.00001 && abs(project.clips[1].trimEndSeconds - 0.6) < 0.00001, "saved trims")
            var expectedCanvas = seed.presentation; expectedCanvas.preset = .square; expectedCanvas.background = .sand
            try need(project.presentation == expectedCanvas && abs(project.durationSeconds - 1.2) < 0.00001, "saved canvas/duration")
            let hashes = try decoder.decode([String: String].self, from: Data(contentsOf: hashesURL))
            for segment in seed.segments { try need(digest(try Data(contentsOf: package.appendingPathComponent(segment.screenPath))) == hashes[segment.screenPath], "original media changed") }
            let output = root.appendingPathComponent("authored-ui-export.mp4")
            let data = try Data(contentsOf: output); try need(!data.isEmpty && data.count < 8 * 1024 * 1024, "output bounds")
            let asset = AVURLAsset(url: output)
            let duration = try await asset.load(.duration)
            let tracks = try await asset.loadTracks(withMediaType: .video)
            try need(tracks.count == 1, "export video track count")
            let size = try await tracks[0].load(.naturalSize)
            try need(abs(duration.seconds - 1.2) <= 1.0 / 30 && size.width == 1080 && size.height == 1080, "native MP4 duration/geometry")
            let first = try await sample(asset: asset, seconds: 0.2), second = try await sample(asset: asset, seconds: 1.0)
            try need(first[2] > first[0] + 80 && first[2] > first[1] + 80 && second[0] > second[2] + 80 && second[0] > second[1] + 80, "decoded edited blue/red frames")
            try need(try !FileManager.default.contentsOfDirectory(atPath: root.path).contains { $0.hasPrefix(".framelet-export-") }, "export staging remains")
            let observation: [String: Any] = ["verified": true, "caseId": "FUI01", "durationSeconds": duration.seconds, "width": size.width, "height": size.height,
                "firstRGB": first, "secondRGB": second, "originalSHA256": hashes, "outputSHA256": digest(data),
                "savedProject": String(data: try encoder.encode(project), encoding: .utf8)!]
            print(String(data: try JSONSerialization.data(withJSONObject: observation, options: .sortedKeys), encoding: .utf8)!)
        }
    }

    static func write(to url: URL, rgb: (UInt8, UInt8, UInt8)) async throws {
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        defer { if writer.status != .completed { writer.cancelWriting() } }
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: 64, AVVideoHeightKey: 48,
            AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 64000, AVVideoMaxKeyFrameIntervalKey: 1]])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: 64, kCVPixelBufferHeightKey as String: 48])
        try need(writer.canAdd(input), "video input"); writer.add(input)
        try need(writer.startWriting(), "video writer"); writer.startSession(atSourceTime: .zero)
        let clock = ContinuousClock(), deadline = ContinuousClock().now.advanced(by: .seconds(10))
        for frame in 0..<12 {
            while !input.isReadyForMoreMediaData {
                try need(clock.now < deadline, "video readiness timeout"); try await Task.sleep(for: .milliseconds(5))
            }
            var buffer: CVPixelBuffer?
            try need(CVPixelBufferCreate(kCFAllocatorDefault, 64, 48, kCVPixelFormatType_32BGRA, nil, &buffer) == kCVReturnSuccess, "pixel buffer")
            guard let pixel = buffer else { throw NSError(domain: "FrameletFixture", code: 3) }
            try need(CVPixelBufferLockBaseAddress(pixel, []) == kCVReturnSuccess, "pixel lock")
            guard let base = CVPixelBufferGetBaseAddress(pixel) else { throw NSError(domain: "FrameletFixture", code: 4) }
            memset(base, 0, CVPixelBufferGetDataSize(pixel))
            for row in 0..<48 {
                let values = base.advanced(by: row * CVPixelBufferGetBytesPerRow(pixel)).assumingMemoryBound(to: UInt8.self)
                for column in 0..<64 { values[column * 4] = rgb.2; values[column * 4 + 1] = rgb.1; values[column * 4 + 2] = rgb.0; values[column * 4 + 3] = 255 }
            }
            CVPixelBufferUnlockBaseAddress(pixel, [])
            try need(adaptor.append(pixel, withPresentationTime: CMTime(value: Int64(frame), timescale: 10)), "video append")
        }
        input.markAsFinished(); writer.endSession(atSourceTime: CMTime(value: 12, timescale: 10)); writer.finishWriting { }
        while writer.status == .writing { try need(clock.now < deadline, "video finish timeout"); try await Task.sleep(for: .milliseconds(5)) }
        try need(writer.status == .completed, "video completion")
    }

    static func sample(asset: AVAsset, seconds: Double) async throws -> [Int] {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero; generator.requestedTimeToleranceAfter = .zero
        let image = try await generator.image(at: CMTime(seconds: seconds, preferredTimescale: 600)).image
        guard let crop = image.cropping(to: CGRect(x: CGFloat(image.width) / 3, y: CGFloat(image.height) / 3,
            width: CGFloat(image.width) / 3, height: CGFloat(image.height) / 3)) else { throw NSError(domain: "FrameletFixture", code: 5) }
        var pixel = [UInt8](repeating: 0, count: 4)
        let rendered = pixel.withUnsafeMutableBytes { bytes -> Bool in
            guard let context = CGContext(data: bytes.baseAddress, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else { return false }
            context.draw(crop, in: CGRect(x: 0, y: 0, width: 1, height: 1)); return true
        }
        try need(rendered, "decoded pixel render"); return pixel.prefix(3).map(Int.init)
    }
}
