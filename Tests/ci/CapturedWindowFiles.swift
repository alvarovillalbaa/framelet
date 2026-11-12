// Read-only verifier for a future actual-window capture case; no capture APIs.
import AVFoundation
import CryptoKit
import Foundation

@main
struct CapturedWindowFiles {
    static let files = FileManager.default
    static func need(_ value: Bool, _ reason: String) throws {
        if !value { throw NSError(domain: "FrameletCapturedWindowFiles", code: 1,
            userInfo: [NSLocalizedDescriptionKey: reason]) }
    }
    static func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
    static func regularData(_ url: URL, maximum: Int) throws -> Data {
        try need(url.standardizedFileURL.path == url.resolvingSymlinksInPath().path, "symlink or noncanonical path")
        let info = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
        try need(info.isRegularFile == true && info.isSymbolicLink != true
            && (info.fileSize ?? Int.max) <= maximum, "file identity/size")
        return try Data(contentsOf: url)
    }
    static func directory(_ url: URL) throws -> [URL] {
        try need(url.standardizedFileURL.path == url.resolvingSymlinksInPath().path, "unsafe directory path")
        let info = try url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        try need(info.isDirectory == true && info.isSymbolicLink != true, "unsafe directory")
        return try files.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isSymbolicLinkKey])
    }
    static func emit(_ value: [String: Any]) throws {
        print(String(data: try JSONSerialization.data(withJSONObject: value, options: .sortedKeys), encoding: .utf8)!)
    }
    struct Snapshot {
        let project: RecordingProject
        let package: URL
        let manifestHash: String
        let originals: [String: String]
    }
    static func snapshot(library: URL, nonce: String) throws -> Snapshot? {
        try need(String(data: try regularData(library.appendingPathComponent(".acceptance-owner"), maximum: 64), encoding: .utf8) == nonce,
            "library owner mismatch")
        let base = library.appendingPathComponent("Recordings", isDirectory: true)
        if !files.fileExists(atPath: base.path) { return nil }
        let packages = try directory(base)
        try need(packages.count <= 1, "unexpected recording count")
        guard let package = packages.first else { return nil }
        let packageChildren = try directory(package)
        try need(package.pathExtension == "framelet", "unexpected package")
        let manifestURL = package.appendingPathComponent("manifest.json")
        guard files.fileExists(atPath: manifestURL.path) else { return nil }
        let data = try regularData(manifestURL, maximum: 4_000_000)
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let project = try decoder.decode(RecordingProject.self, from: data)
        try need(package.lastPathComponent == project.id.uuidString + ".framelet", "package UUID")
        try validateRecording(project)
        guard project.status == .ready else { return nil }
        try need(project.segments.count == 2 && project.clips.count == 2, "expected two sealed takes")
        try need(!project.options.capturesSystemAudio && !project.options.capturesMicrophone
            && !project.options.cameraEnabled, "unexpected audio/camera option")
        try need(project.presentation.preset == .landscape && project.presentation.layout == .screenOnly,
            "unexpected presentation")
        try need(Set(packageChildren.map(\.lastPathComponent)) == ["manifest.json", "segments"], "unexpected package files")
        let segmentFolder = package.appendingPathComponent("segments", isDirectory: true)
        let media = try directory(segmentFolder)
        try need(media.count == 2, "unexpected media count")
        var originals: [String: String] = [:]
        for (index, segment) in project.segments.enumerated() {
            try need(segment.cameraPath == nil && segment.cameraOffsetSeconds == nil, "unexpected camera sidecar")
            try need(segment.screenPath == "segments/\(segment.id.uuidString)-screen.mp4", "unexpected screen path")
            let clip = project.clips[index]
            try need(clip.segmentID == segment.id && clip.trimStartSeconds == 0
                && abs(clip.trimEndSeconds - segment.durationSeconds) <= 0.000001, "ordered full-take clips")
            let url = package.appendingPathComponent(segment.screenPath)
            let raw = try regularData(url, maximum: 32 * 1024 * 1024)
            try need(!raw.isEmpty && media.contains(url), "missing original")
            originals[segment.screenPath] = digest(raw)
        }
        return Snapshot(project: project, package: package, manifestHash: digest(data), originals: originals)
    }
    static func main() async throws {
        try need(CommandLine.arguments.count == 3, "expected snapshot|verify and owned config")
        let mode = CommandLine.arguments[1]
        try need(["snapshot", "verify"].contains(mode), "invalid mode")
        let configData = try regularData(URL(fileURLWithPath: CommandLine.arguments[2]), maximum: 65536)
        let config = try JSONSerialization.jsonObject(with: configData) as! [String: String]
        guard let libraryPath = config["library"], let nonce = config["nonce"], let rootPath = config["root"] else {
            throw NSError(domain: "FrameletCapturedWindowFiles", code: 2)
        }
        try need(nonce.range(of: "^[a-f0-9]{32}$", options: .regularExpression) != nil, "invalid owner nonce")
        let root = URL(fileURLWithPath: rootPath, isDirectory: true)
        let library = URL(fileURLWithPath: libraryPath, isDirectory: true)
        _ = try directory(root)
        try need(String(data: try regularData(root.appendingPathComponent("owner"), maximum: 64), encoding: .utf8) == nonce, "scratch owner")
        if mode == "snapshot" {
            let deadline = ProcessInfo.processInfo.systemUptime + 120
            while ProcessInfo.processInfo.systemUptime < deadline {
                if let state = try snapshot(library: library, nonce: nonce) {
                    try emit(["kind": "captured-window-originals-before-export", "projectID": state.project.id.uuidString,
                        "originalSHA256": state.originals, "manifestSHA256": state.manifestHash,
                        "snapshotFinishedUptime": ProcessInfo.processInfo.systemUptime])
                    return
                }
                try await Task.sleep(nanoseconds: 100_000_000)
            }
            throw NSError(domain: "FrameletCapturedWindowFiles", code: 3,
                userInfo: [NSLocalizedDescriptionKey: "No ready two-take recording within owned snapshot deadline"])
        }
        guard let state = try snapshot(library: library, nonce: nonce) else {
            throw NSError(domain: "FrameletCapturedWindowFiles", code: 4)
        }
        let baseline = try JSONSerialization.jsonObject(with: regularData(root.appendingPathComponent("originals-before.json"),
            maximum: 65536)) as! [String: Any]
        let observation = try JSONSerialization.jsonObject(with: regularData(root.appendingPathComponent("capture-observations.json"),
            maximum: 65536)) as! [String: Any]
        try need(baseline["projectID"] as? String == state.project.id.uuidString
            && baseline["originalSHA256"] as? [String: String] == state.originals
            && baseline["manifestSHA256"] as? String == state.manifestHash, "originals/manifest changed after snapshot")
        guard let times = observation["uptime"] as? [String: Double],
              let snapshotTime = baseline["snapshotFinishedUptime"] as? Double else {
            throw NSError(domain: "FrameletCapturedWindowFiles", code: 5)
        }
        let names = ["startRequested", "firstRecordingObserved", "pauseRequested", "pauseReady",
            "resumeRequested", "secondRecordingObserved", "stopRequested", "finalReady", "exportRequested"]
        let values = try names.map { name -> Double in
            guard let value = times[name], value.isFinite else { throw NSError(domain: "FrameletCapturedWindowFiles", code: 6) }
            return value
        }
        try need(zip(values, values.dropFirst()).allSatisfy { $0 <= $1 }, "nonmonotonic UI observations")
        // The sealed manifest can become ready just before the UI publishes its
        // Ready label. Both are after Stop; the snapshot must precede Export.
        try need(values[6] <= snapshotTime && snapshotTime < values[8], "snapshot must precede real export action")
        let gap = values[4] - values[3]
        try need(gap >= 4 && gap <= 30, "deliberate paused interval not observed")
        let sum = state.project.segments.reduce(0) { $0 + $1.durationSeconds }
        try need(sum >= 4 && sum <= 30 && sum <= values[7] - values[0] - gap + 0.5, "pause interval entered media timeline")
        var inspected: [[String: Any]] = []
        for (index, segment) in state.project.segments.enumerated() {
            inspected.append(try await inspect(state.package.appendingPathComponent(segment.screenPath),
                expectedDuration: segment.durationSeconds, expectedExport: false,
                samples: [(segment.durationSeconds / 2, index == 1)]))
        }
        let output = root.appendingPathComponent("authored-window-export.mp4")
        let exported = try await inspect(output, expectedDuration: sum, expectedExport: true,
            samples: [(state.project.segments[0].durationSeconds / 2, false),
                (state.project.segments[0].durationSeconds + state.project.segments[1].durationSeconds / 2, true)])
        try need(try snapshot(library: library, nonce: nonce)?.originals == state.originals, "verification changed originals")
        try emit(["kind": "framelet-actual-window-capture-files", "verified": true,
            "originalsUnchangedBeforeAfterExport": true, "segments": inspected, "export": exported,
            "pauseMinimumSeconds": gap, "concatenatedDurationSeconds": sum,
            "screenAnchorEncodedSampleCorrespondenceMeasured": false, "captureAPIsUsedByVerifier": false])
    }
    static func inspect(_ url: URL, expectedDuration: Double, expectedExport: Bool,
                        samples: [(Double, Bool)]) async throws -> [String: Any] {
        let data = try regularData(url, maximum: 32 * 1024 * 1024)
        let asset = AVURLAsset(url: url)
        let video = try await asset.loadTracks(withMediaType: .video)
        let audio = try await asset.loadTracks(withMediaType: .audio)
        try need(video.count == 1 && audio.isEmpty, "unexpected video/audio tracks")
        let range = try await video[0].load(.timeRange)
        let size = try await video[0].load(.naturalSize)
        try need(range.duration.seconds.isFinite && abs(range.duration.seconds - expectedDuration) <= 1.0 / 30,
            "video duration differs from sealed manifest/timeline")
        if expectedExport { try need(size == CGSize(width: 1920, height: 1080), "landscape export geometry") }
        else {
            try need(size.width >= 320 && size.width <= 1920 && size.height >= 200 && size.height <= 1080
                && size.width / size.height > 1.4 && size.width / size.height < 1.8, "authored window geometry")
        }
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero; generator.requestedTimeToleranceAfter = .zero
        var decoded: [[String: Any]] = []
        for (seconds, blue) in samples {
            let frame = try await generator.image(at: CMTime(seconds: range.start.seconds + seconds, preferredTimescale: 600)).image
            guard let crop = frame.cropping(to: CGRect(x: frame.width / 2 - 16, y: frame.height / 2 - 16, width: 32, height: 32)) else {
                throw NSError(domain: "FrameletCapturedWindowFiles", code: 7)
            }
            var pixel = [UInt8](repeating: 0, count: 4)
            let rendered = pixel.withUnsafeMutableBytes { bytes -> Bool in
                guard let context = CGContext(data: bytes.baseAddress, width: 1, height: 1, bitsPerComponent: 8,
                    bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else { return false }
                context.draw(crop, in: CGRect(x: 0, y: 0, width: 1, height: 1)); return true
            }
            try need(rendered, "decode center pixel")
            let rgb = pixel.prefix(3).map(Int.init)
            try need(blue ? rgb[2] > rgb[0] + 80 && rgb[2] > rgb[1] + 80
                         : rgb[0] > rgb[2] + 80 && rgb[0] > rgb[1] + 80, "captured authored colour/order")
            decoded.append(["seconds": seconds, "expected": blue ? "blue" : "red", "centerRGB": rgb])
        }
        return ["file": url.lastPathComponent, "bytes": data.count, "sha256": digest(data),
            "width": size.width, "height": size.height, "durationSeconds": range.duration.seconds,
            "videoTracks": video.count, "audioTracks": audio.count, "samples": decoded]
    }
}
