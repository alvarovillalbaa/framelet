// Forensic inspection of a retained authored export. Never launches Framelet.
import AVFoundation
import CryptoKit
import Foundation

@main
struct InspectExport {
    static func need(_ value: Bool, _ reason: String) throws {
        if !value { throw NSError(domain: "FrameletExportInspection", code: 1,
            userInfo: [NSLocalizedDescriptionKey: reason]) }
    }

    static func main() async throws {
        try need(CommandLine.arguments.count == 3, "expected existing export and SHA-256")
        let url = URL(fileURLWithPath: CommandLine.arguments[1])
        let data = try Data(contentsOf: url)
        try need(!data.isEmpty && data.count <= 8 * 1024 * 1024, "export size")
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        try need(digest == CommandLine.arguments[2], "retained export changed")
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        try need(tracks.count == 1, "video track count")
        let size = try await tracks[0].load(.naturalSize)
        try need(size == CGSize(width: 1080, height: 1080)
            && abs(duration.seconds - 1.2) <= 1.0 / 30, "geometry or duration")
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        var samples: [[String: Any]] = []
        for seconds in [0.2, 1.0] {
            let image = try await generator.image(at: CMTime(seconds: seconds, preferredTimescale: 600)).image
            try need(image.width == 1080 && image.height == 1080, "decoded frame size")
            let center = try rgb(image, rect: CGRect(x: 360, y: 360, width: 360, height: 360))
            let corners = try [CGRect(x: 8, y: 8, width: 16, height: 16),
                CGRect(x: 1056, y: 8, width: 16, height: 16),
                CGRect(x: 8, y: 1056, width: 16, height: 16),
                CGRect(x: 1056, y: 1056, width: 16, height: 16)].map { try rgb(image, rect: $0) }
            samples.append(["seconds": seconds, "centerRGB": center, "cornerRGB": corners])
            // Saved Sand is RGB (0.94, 0.90, 0.81); allow codec/colour conversion.
            try need(corners.allSatisfy { zip($0, [240, 230, 207]).allSatisfy { abs($0 - $1) <= 18 } },
                "rendered Sand background differs: \(corners)")
            if seconds == 0.2 {
                try need(center[2] > center[0] + 80 && center[2] > center[1] + 80, "first clip is not blue")
            } else {
                try need(center[0] > center[2] + 80 && center[0] > center[1] + 80, "second clip is not red")
            }
        }
        let result: [String: Any] = ["verified": true, "kind": "framelet-retained-export-inspection",
            "sha256": digest, "bytes": data.count, "durationSeconds": duration.seconds,
            "width": size.width, "height": size.height, "samples": samples,
            "applicationLaunched": false, "uiCaseReplayed": false]
        print(String(data: try JSONSerialization.data(withJSONObject: result, options: .sortedKeys), encoding: .utf8)!)
    }

    static func rgb(_ image: CGImage, rect: CGRect) throws -> [Int] {
        guard let crop = image.cropping(to: rect) else {
            throw NSError(domain: "FrameletExportInspection", code: 2)
        }
        var pixel = [UInt8](repeating: 0, count: 4)
        let rendered = pixel.withUnsafeMutableBytes { bytes -> Bool in
            guard let context = CGContext(data: bytes.baseAddress, width: 1, height: 1,
                bitsPerComponent: 8, bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else { return false }
            context.draw(crop, in: CGRect(x: 0, y: 0, width: 1, height: 1))
            return true
        }
        try need(rendered, "pixel render")
        return pixel.prefix(3).map(Int.init)
    }
}
