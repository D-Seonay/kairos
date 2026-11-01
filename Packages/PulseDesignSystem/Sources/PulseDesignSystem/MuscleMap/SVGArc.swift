import CoreGraphics
import Foundation

/// Conversion d'un arc elliptique SVG en courbes de Bézier cubiques
/// (SVG 1.1, annexe F.6 : paramétrage par les extrémités → paramétrage par le centre).
enum SVGArc {
    // swiftlint:disable:next large_tuple
    typealias CubicSegment = (control1: CGPoint, control2: CGPoint, end: CGPoint)

    // Chaque segment est `(contrôle 1, contrôle 2, extrémité)`. `rotation` est en degrés.
    // swiftlint:disable:next function_parameter_count
    static func cubicSegments(
        from start: CGPoint, to end: CGPoint, rx: Double, ry: Double, rotation: Double, largeArc: Bool, sweep: Bool
    ) -> [CubicSegment] {
        guard start != end else { return [] }
        var radiusX = abs(rx)
        var radiusY = abs(ry)
        guard radiusX > 0, radiusY > 0 else { return [straightLine(from: start, to: end)] }

        let phi = rotation * .pi / 180
        let cosPhi = cos(phi)
        let sinPhi = sin(phi)
        let halfDX = (start.x - end.x) / 2
        let halfDY = (start.y - end.y) / 2
        let x1 = cosPhi * halfDX + sinPhi * halfDY
        let y1 = -sinPhi * halfDX + cosPhi * halfDY

        let lambda = (x1 * x1) / (radiusX * radiusX) + (y1 * y1) / (radiusY * radiusY)
        if lambda > 1 {
            radiusX *= lambda.squareRoot()
            radiusY *= lambda.squareRoot()
        }
        let rx2 = radiusX * radiusX
        let ry2 = radiusY * radiusY
        let numerator = rx2 * ry2 - rx2 * y1 * y1 - ry2 * x1 * x1
        let denominator = rx2 * y1 * y1 + ry2 * x1 * x1
        let coefficient = (largeArc == sweep ? -1.0 : 1.0) * max(0, numerator / denominator).squareRoot()
        let cxPrime = coefficient * radiusX * y1 / radiusY
        let cyPrime = -coefficient * radiusY * x1 / radiusX
        let centre = CGPoint(
            x: cosPhi * cxPrime - sinPhi * cyPrime + (start.x + end.x) / 2,
            y: sinPhi * cxPrime + cosPhi * cyPrime + (start.y + end.y) / 2)

        let startAngle = atan2((y1 - cyPrime) / radiusY, (x1 - cxPrime) / radiusX)
        let endAngle = atan2((-y1 - cyPrime) / radiusY, (-x1 - cxPrime) / radiusX)
        var sweepAngle = endAngle - startAngle
        if !sweep && sweepAngle > 0 { sweepAngle -= 2 * .pi }
        if sweep && sweepAngle < 0 { sweepAngle += 2 * .pi }

        let frame = Frame(centre: centre, radiusX: radiusX, radiusY: radiusY, cosPhi: cosPhi, sinPhi: sinPhi)
        return segments(frame: frame, startAngle: startAngle, sweepAngle: sweepAngle, end: end)
    }

    private struct Frame {
        let centre: CGPoint
        let radiusX: Double
        let radiusY: Double
        let cosPhi: Double
        let sinPhi: Double

        /// Point du cercle unité envoyé dans le repère de l'ellipse.
        func map(_ unitX: Double, _ unitY: Double) -> CGPoint {
            CGPoint(
                x: cosPhi * radiusX * unitX - sinPhi * radiusY * unitY + centre.x,
                y: sinPhi * radiusX * unitX + cosPhi * radiusY * unitY + centre.y)
        }
    }

    private static func segments(
        frame: Frame, startAngle: Double, sweepAngle: Double, end: CGPoint
    ) -> [CubicSegment] {
        let count = max(1, Int((abs(sweepAngle) / (.pi / 2) - 1e-9).rounded(.up)))
        let step = sweepAngle / Double(count)
        let handle = 4.0 / 3.0 * tan(step / 4)
        return (0..<count).map { index in
            let from = startAngle + Double(index) * step
            let to = from + step
            let control1 = frame.map(cos(from) - handle * sin(from), sin(from) + handle * cos(from))
            let control2 = frame.map(cos(to) + handle * sin(to), sin(to) - handle * cos(to))
            // Le dernier point est exactement l'extrémité demandée, sans dérive d'arrondi.
            let point = index == count - 1 ? end : frame.map(cos(to), sin(to))
            return (control1, control2, point)
        }
    }

    private static func straightLine(from start: CGPoint, to end: CGPoint) -> CubicSegment {
        let third = CGPoint(x: (end.x - start.x) / 3, y: (end.y - start.y) / 3)
        return (
            CGPoint(x: start.x + third.x, y: start.y + third.y),
            CGPoint(x: end.x - third.x, y: end.y - third.y),
            end
        )
    }
}
