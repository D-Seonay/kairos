import SwiftUI

/// Une tendance sans axe : une ligne continue par série de valeurs consécutives, un trou coupe la ligne,
/// un point plein marque la dernière valeur présente. Masquée à VoiceOver : la tuile qui la porte a l'étiquette.
public struct Sparkline: View {
    private let values: [Double?]
    private let color: Color
    private let lineWidth: CGFloat

    public init(values: [Double?], color: Color, lineWidth: CGFloat = 2) {
        self.values = values
        self.color = color
        self.lineWidth = lineWidth
    }

    public var body: some View {
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size)
            let points = SparklineGeometry.points(values: values, in: rect, inset: lineWidth * 1.5)
            context.stroke(
                Self.path(through: points),
                with: .color(color),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
            )
            if let last = points.compactMap({ $0 }).last {
                let radius = lineWidth * 1.25
                let dot = CGRect(x: last.x - radius, y: last.y - radius, width: 2 * radius, height: 2 * radius)
                context.fill(Path(ellipseIn: dot), with: .color(color))
            }
        }
        .accessibilityHidden(true)
    }

    /// Un segment entre deux valeurs consécutives présentes ; une valeur isolée ne trace rien (le point la montre).
    static func path(through points: [CGPoint?]) -> Path {
        var path = Path()
        for (previous, next) in zip(points, points.dropFirst()) {
            guard let previous, let next else { continue }
            path.move(to: previous)
            path.addLine(to: next)
        }
        return path
    }
}

#Preview("Sparkline, avec trous") {
    VStack(alignment: .leading, spacing: 20) {
        Sparkline(values: [42, 44, 41, 47, 49, 46, 52], color: PulsePalette.ok)
        Sparkline(values: [60, 58, nil, nil, 55, 57, 52], color: PulsePalette.warn)
        Sparkline(values: [nil, 61, nil, 59, 63, nil], color: PulsePalette.run, lineWidth: 3)
        Sparkline(values: [50, 50, 50], color: PulsePalette.text)
    }
    .frame(width: 120, height: 220)
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(PulsePalette.surface)
}
