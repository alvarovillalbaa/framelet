import CoreGraphics
import FrameletCore

/// AVVideoComposition uses top-left coordinates, unlike a default CALayer canvas.
enum ExportGeometry {
    struct Placement {
        let transform: CGAffineTransform
        let sourceCrop: CGRect
    }

    static func placement(size: CGSize, preferredTransform: CGAffineTransform,
                          rect: NormalizedRect, canvas: CGSize,
                          fill: Bool, mirrored: Bool = false) throws -> Placement {
        let values = [size.width, size.height, preferredTransform.a, preferredTransform.b,
                      preferredTransform.c, preferredTransform.d, preferredTransform.tx,
                      preferredTransform.ty, canvas.width, canvas.height]
        guard values.allSatisfy(\.isFinite), size.width > 0, size.height > 0,
              canvas.width > 0, canvas.height > 0 else { throw ExportFailure.invalidMedia }
        let coordinates = [rect.x, rect.y, rect.width, rect.height]
        guard coordinates.allSatisfy(\.isFinite), rect.x >= 0, rect.y >= 0,
              rect.width > 0, rect.height > 0,
              rect.x + rect.width <= 1.000001, rect.y + rect.height <= 1.000001 else {
            throw RecordingValidationError.invalidPresentation
        }
        // Recorded camera orientations are axis-aligned rotations/reflections. A
        // sheared/oblique imported track needs a different compositor to crop safely.
        let t = preferredTransform
        let epsilon: CGFloat = 0.000001
        let straight = abs(t.b) < epsilon && abs(t.c) < epsilon
        let rotated = abs(t.a) < epsilon && abs(t.d) < epsilon
        guard (straight || rotated), abs(t.a * t.d - t.b * t.c) > epsilon else {
            throw ExportFailure.unsupportedOrientation
        }
        let source = CGRect(origin: .zero, size: size)
        let oriented = source.applying(t).standardized
        guard oriented.width > 0, oriented.height > 0 else { throw ExportFailure.invalidMedia }
        let target = CGRect(x: CGFloat(rect.x) * canvas.width, y: CGFloat(rect.y) * canvas.height,
                            width: CGFloat(rect.width) * canvas.width, height: CGFloat(rect.height) * canvas.height)
        let ratioX = target.width / oriented.width
        let ratioY = target.height / oriented.height
        let scale = fill ? max(ratioX, ratioY) : min(ratioX, ratioY)
        var transform = t.concatenating(CGAffineTransform(translationX: -oriented.minX, y: -oriented.minY))
        if mirrored {
            transform = transform.concatenating(CGAffineTransform(a: -1, b: 0, c: 0, d: 1,
                                                                  tx: oriented.width, ty: 0))
        }
        transform = transform
            .concatenating(CGAffineTransform(scaleX: scale, y: scale))
            .concatenating(CGAffineTransform(translationX: target.midX - oriented.width * scale / 2,
                                            y: target.midY - oriented.height * scale / 2))
        // Crop in the source buffer's top-left space BEFORE applying the transform.
        // This also clips a filled camera to its exact PiP/side-by-side rectangle.
        let crop = target.applying(transform.inverted()).standardized.intersection(source)
        guard !crop.isNull, !crop.isEmpty else { throw ExportFailure.invalidMedia }
        return Placement(transform: transform, sourceCrop: crop)
    }
}
