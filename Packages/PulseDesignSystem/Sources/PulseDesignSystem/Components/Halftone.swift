import SwiftUI

/// La trame de points, le motif de la direction « Argentique » : une grille de points dont le rayon dit l'intensité, comme une
/// photo imprimée en simili : encre noire sur le papier, argent sur le noir. Un seul tracé rempli d'un coup, pour rester
/// léger même avec des milliers de points.
public struct HalftoneField: View {
    private let spacing: CGFloat
    private let maxRadius: CGFloat
    private let color: Color
    private let light: @Sendable (CGPoint) -> Double

    /// `light` donne la lumière (0…1) en un point exprimé en part du rectangle (0…1 sur chaque axe).
    public init(spacing: CGFloat = 7, maxRadius: CGFloat? = nil, color: Color = PulsePalette.ink,
                light: @escaping @Sendable (CGPoint) -> Double) {
        self.spacing = spacing
        self.maxRadius = maxRadius ?? spacing * 0.46
        self.color = color
        self.light = light
    }

    public var body: some View {
        Canvas { context, size in
            context.fill(Halftone.dots(in: size, spacing: spacing, maxRadius: maxRadius, light: light), with: .color(color))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

public enum Halftone {
    /// Les points de la trame, rangées décalées d'un demi-pas comme une vraie trame. Un point sous 0,15 pt n'est pas tracé.
    public static func dots(in size: CGSize, spacing: CGFloat, maxRadius: CGFloat,
                            light: (CGPoint) -> Double) -> Path {
        var path = Path()
        guard spacing > 0, size.width > 0, size.height > 0 else { return path }
        let rowStep = spacing * 0.866
        var row = 0
        var y = rowStep / 2
        while y < size.height {
            var x = row.isMultiple(of: 2) ? spacing / 2 : spacing
            while x < size.width {
                let level = min(max(light(CGPoint(x: x / size.width, y: y / size.height)), 0), 1)
                let radius = maxRadius * CGFloat(level.squareRoot())
                if radius >= 0.15 {
                    path.addEllipse(in: CGRect(x: x - radius, y: y - radius, width: 2 * radius, height: 2 * radius))
                }
                x += spacing
            }
            y += rowStep
            row += 1
        }
        return path
    }

    /// Une source de lumière douce : 1 au centre, qui s'éteint en cloche sur `spread` (en part du rectangle).
    public static func glow(at point: CGPoint, center: CGPoint, spread: Double) -> Double {
        let dx = Double(point.x - center.x)
        let dy = Double(point.y - center.y)
        return exp(-(dx * dx + dy * dy) / (2 * spread * spread))
    }
}

#Preview {
    HalftoneField { point in Halftone.glow(at: point, center: CGPoint(x: 0.8, y: 0.15), spread: 0.4) }
        .frame(height: 300)
        .background(.black)
}
