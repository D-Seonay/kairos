import SwiftUI

/// La barre de charge d'entraînement (ratio 7 j / 28 j), en rangée de points : creux en sous-charge, pleins et blancs dans la
/// zone optimale, gris en vigilance, du signal dans le risque. Un anneau marque le ratio et les points déjà parcourus
/// s'allument. Les libellés nomment les zones, la couleur ne porte pas seule le sens.
public struct LoadGauge: View {
    private static let dotCount = 34
    private static let markerDiameter: CGFloat = 20
    private static let markerBorder: CGFloat = 3

    private let ratio: Double
    private let accessibilityLabel: String
    @ScaledMetric(relativeTo: .caption2) private var labelSize: CGFloat = 11.5

    public init(ratio: Double, accessibilityLabel: String) {
        self.ratio = ratio
        self.accessibilityLabel = accessibilityLabel
    }

    public var body: some View {
        VStack(spacing: 8) {
            bar
            labels
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    // MARK: Barre

    private var bar: some View {
        Canvas { context, size in
            let count = Self.dotCount
            let step = size.width / CGFloat(count)
            let radius = min(step * 0.32, 3.2)
            let midY = size.height / 2
            let position = LoadGaugeGeometry.fraction(ratio: ratio)
            for index in 0..<count {
                let fraction = (Double(index) + 0.5) / Double(count)
                let center = CGPoint(x: step * (CGFloat(index) + 0.5), y: midY)
                let dot = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: 2 * radius,
                                                 height: 2 * radius))
                let zone = Self.zone(for: fraction)
                let lit = fraction <= position
                if zone == 0 {
                    context.stroke(dot, with: .color(PulsePalette.text2.opacity(lit ? 0.9 : 0.45)), lineWidth: 1)
                } else {
                    context.fill(dot, with: .color(Self.zoneColors[zone].opacity(lit ? 1 : 0.4)))
                }
            }
            let markerRadius = Self.markerDiameter / 2
            let markerX = min(max(size.width * position, markerRadius), size.width - markerRadius)
            let marker = CGRect(x: markerX - markerRadius, y: midY - markerRadius, width: Self.markerDiameter,
                                height: Self.markerDiameter)
            context.fill(Path(ellipseIn: marker), with: .color(PulsePalette.background))
            context.stroke(Path(ellipseIn: marker.insetBy(dx: 1, dy: 1)), with: .color(PulsePalette.text), lineWidth: 2)
            context.fill(Path(ellipseIn: marker.insetBy(dx: Self.markerBorder + 3, dy: Self.markerBorder + 3)),
                         with: .color(PulsePalette.text))
        }
        .frame(height: Self.markerDiameter)
    }

    /// Sous-charge, optimal, vigilance, risque : les zones de `LoadGaugeGeometry.zoneBounds`.
    private static let zoneColors = [PulsePalette.text2, PulsePalette.text, PulsePalette.warn, PulsePalette.bad]

    private static func zone(for fraction: Double) -> Int {
        let bounds = LoadGaugeGeometry.zoneBounds
        return (1..<bounds.count).first { fraction < bounds[$0] }.map { $0 - 1 } ?? zoneColors.count - 1
    }

    // MARK: Libellés

    /// En ligne tant que les trois libellés tiennent, empilés aux grandes tailles de texte.
    private var labels: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                label(Self.underTrainingLabel)
                Spacer(minLength: 0)
                label(Self.optimalLabel)
                Spacer(minLength: 0)
                label(Self.riskLabel)
            }
            VStack(alignment: .leading, spacing: 4) {
                label(Self.underTrainingLabel)
                label(Self.optimalLabel)
                label(Self.riskLabel)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.system(size: labelSize))
            .foregroundStyle(PulsePalette.muted)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
    }

    private static var underTrainingLabel: String { String(localized: "Sous-entraînement", bundle: .module) }
    private static var optimalLabel: String { String(localized: "0,8 à 1,3", bundle: .module) }
    private static var riskLabel: String { String(localized: "Risque", bundle: .module) }
}

#Preview("Jauge de charge") {
    VStack(spacing: 28) {
        LoadGauge(ratio: 0.6, accessibilityLabel: "Charge 0,6 : sous-entraînement")
        LoadGauge(ratio: 1.12, accessibilityLabel: "Charge 1,12 : zone optimale")
        LoadGauge(ratio: 1.7, accessibilityLabel: "Charge 1,7 : risque")
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(PulsePalette.background)
}
