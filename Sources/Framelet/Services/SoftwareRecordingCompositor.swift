import AVFoundation
import CoreImage
import CoreVideo
import Foundation

// Preview uses the export builder's static layer instructions. A software
// context also works where the system playback compositor produces no pixels.
// Mutable state is locked; rendering and request completion use one queue.
final class SoftwareRecordingCompositor: NSObject, AVVideoCompositing, @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.alvarovillalbaa.Framelet.preview-composition")
    private let queueKey = DispatchSpecificKey<UInt8>()
    private let lock = NSLock()
    private var generation = 0
    private let context = CIContext(options: [.useSoftwareRenderer: true, .cacheIntermediates: false])
    private let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!

    override init() {
        super.init()
        queue.setSpecific(key: queueKey, value: 1)
    }

    static func videoComposition(from original: AVVideoComposition) throws -> AVVideoComposition {
        guard let result = original.mutableCopy() as? AVMutableVideoComposition else { throw failure() }
        result.customVideoCompositorClass = SoftwareRecordingCompositor.self
        return result
    }

    var sourcePixelBufferAttributes: [String: Any]? {
        [kCVPixelBufferPixelFormatTypeKey as String: [kCVPixelFormatType_32BGRA]]
    }

    var requiredPixelBufferAttributesForRenderContext: [String: Any] {
        [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
    }

    func renderContextChanged(_ newRenderContext: AVVideoCompositionRenderContext) {
        lock.lock(); generation += 1; lock.unlock()
    }

    func startRequest(_ request: AVAsynchronousVideoCompositionRequest) {
        lock.lock(); let token = generation; lock.unlock()
        queue.async { [self] in
            guard current(token) else { request.finishCancelledRequest(); return }
            do {
                let buffer = try render(request)
                if current(token) { request.finish(withComposedVideoFrame: buffer) }
                else { request.finishCancelledRequest() }
            } catch {
                if current(token) { request.finish(with: error) }
                else { request.finishCancelledRequest() }
            }
        }
    }

    func cancelAllPendingVideoCompositionRequests() {
        lock.lock(); generation += 1; lock.unlock()
        // AVFoundation requires pending requests to finish before returning.
        // A reentrant call from a finishing callback must not sync onto itself.
        if DispatchQueue.getSpecific(key: queueKey) == nil { queue.sync {} }
    }

    private func current(_ token: Int) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return generation == token
    }

    private func render(_ request: AVAsynchronousVideoCompositionRequest) throws -> CVPixelBuffer {
        guard let instruction = request.videoCompositionInstruction as? AVVideoCompositionInstruction,
              let buffer = request.renderContext.newPixelBuffer() else { throw Self.failure() }
        let size = request.renderContext.videoComposition.renderSize
        let canvasBounds = CGRect(origin: .zero, size: size)
        guard size.width.isFinite, size.height.isFinite, size.width > 0, size.height > 0 else { throw Self.failure() }
        let background = instruction.backgroundColor ?? CGColor(gray: 0, alpha: 1)
        var canvas = CIImage(color: CIColor(cgColor: background)).cropped(to: canvasBounds)
        for layer in instruction.layerInstructions.reversed() {
            guard let source = request.sourceFrame(byTrackID: layer.trackID) else { throw Self.failure() }
            let width = CGFloat(CVPixelBufferGetWidth(source)), height = CGFloat(CVPixelBufferGetHeight(source))
            var transform = CGAffineTransform.identity, transformEnd = CGAffineTransform.identity
            var timeRange = CMTimeRange.invalid
            if layer.getTransformRamp(for: request.compositionTime, start: &transform, end: &transformEnd, timeRange: &timeRange) {
                guard transform == transformEnd else { throw Self.failure() }
            }
            var crop = CGRect(x: 0, y: 0, width: width, height: height), cropEnd = CGRect.zero
            if layer.getCropRectangleRamp(for: request.compositionTime, start: &crop, end: &cropEnd, timeRange: &timeRange) {
                guard crop == cropEnd else { throw Self.failure() }
            }
            var opacity: Float = 1, opacityEnd: Float = 1
            if layer.getOpacityRamp(for: request.compositionTime, start: &opacity, end: &opacityEnd, timeRange: &timeRange) {
                guard opacity == 1, opacityEnd == 1 else { throw Self.failure() }
            }
            guard !crop.isNull, !crop.isEmpty,
                  [crop.minX, crop.minY, crop.width, crop.height, transform.a, transform.b,
                   transform.c, transform.d, transform.tx, transform.ty].allSatisfy(\.isFinite) else { throw Self.failure() }
            // CI is bottom-left; the shared crop/transform contract is top-left.
            let sourceFlip = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: height)
            let image = CIImage(cvPixelBuffer: source)
                .transformed(by: sourceFlip).cropped(to: crop).transformed(by: transform)
            canvas = image.composited(over: canvas).cropped(to: canvasBounds)
        }
        let outputBounds = CGRect(x: 0, y: 0, width: CGFloat(CVPixelBufferGetWidth(buffer)), height: CGFloat(CVPixelBufferGetHeight(buffer)))
        let outputFlip = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: outputBounds.height)
        let image = canvas.transformed(by: request.renderContext.renderTransform)
            .transformed(by: outputFlip).cropped(to: outputBounds)
        context.render(image, to: buffer, bounds: outputBounds, colorSpace: colorSpace)
        return buffer
    }

    private static func failure() -> NSError {
        NSError(domain: "FrameletSoftwarePreview", code: 1,
            userInfo: [NSLocalizedDescriptionKey: "The recording preview could not be rendered. Original files have been retained."])
    }
}
