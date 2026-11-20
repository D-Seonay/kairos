import SwiftUI

/// Une tendance sans axe, en pointillé d'instrument : un point par valeur, reliés par un filet fin, un trou coupe le filet ;
/// une trame de points, plus dense en haut, descend sous chaque série ; un anneau marque la dernière valeur présente.
/// Masquée à VoiceOver : la tuile qui la porte a l'étiquette.
public struct Sparkline: View {
    private let values: [Double?]
    private let color: Color
    private let lineWidth: CGFloat
    private let cardColor: Color

    /// `cardColor` est le fond sur lequel la courbe est posée : il évide l'anneau de la dernière valeur.
    public init(values: [Double?], color: Color, lineWidth: CGFloat = 2, cardColor: Color = PulsePalette.surface) {
        self.values = values
        self.color = color
        self.lineWidth = lineWidth
        self.cardColor = cardColor
    }

    public var body: some View {
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size)
            let points = SparklineGeometry.points(values: values, in: rect, inset: lineWidth * 2)
            // La trame sous la courbe : découpée par l'aire, elle s'éteint vers le bas.
            context.drawLayer { layer in
                layer.clip(to: Self.area(through: points, bottom: rect.maxY))
                layer.fill(
                    Halftone.dots(in: size, spacing: 4, maxRadius: 0.9) { 1 - Double($0.y) },
                    with: .color(color.opacity(0.45))
                )
            }
            context.stroke(
                Self.path(through: points),
                with: .color(color.opacity(0.45)),
                style: StrokeStyle(lineWidth: max(lineWidth * 0.5, 0.75), lineCap: .round, lineJoin: .round)
            )
            let present = points.compactMap { $0 }
            let radius = lineWidth * 0.9
            var dots = Path()
            for point in present.dropLast() {
                dots.addEllipse(in: CGRect(x: point.x - radius, y: point.y - radius, width: 2 * radius, height: 2 * radius))
            }
            context.fill(dots, with: .color(color))
            if let last = present.last {
                let ring = radius * 2.2
                let ringRect = CGRect(x: last.x - ring, y: last.y - ring, width: 2 * ring, height: 2 * ring)
                context.fill(Path(ellipseIn: ringRect), with: .color(cardColor))
                context.stroke(Path(ellipseIn: ringRect.insetBy(dx: 0.6, dy: 0.6)), with: .color(color), lineWidth: 1.2)
                context.fill(Path(ellipseIn: ringRect.insetBy(dx: ring * 0.55, dy: ring * 0.55)), with: .color(color))
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

    /// L'aire sous la ligne, où va la trame : un polygone fermé jusqu'à `bottom` par série d'au moins deux valeurs consécutives.
    nonisolated static func area(through points: [CGPoint?], bottom: CGFloat) -> Path {
        var path = Path()
        var run: [CGPoint] = []
        func close() {
            if run.count > 1, let first = run.first, let last = run.last {
                path.move(to: CGPoint(x: first.x, y: bottom))
                run.forEach { path.addLine(to: $0) }
                path.addLine(to: CGPoint(x: last.x, y: bottom))
                path.closeSubpath()
            }
            run.removeAll()
        }
        for point in points {
            if let point { run.append(point) } else { close() }
        }
        close()
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
