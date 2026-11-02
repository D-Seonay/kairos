import SwiftUI

/// La barre de charge d'entraînement (ratio 7 j / 28 j) de la maquette : quatre zones de couleur
/// et un repère rond à la position du ratio. Les libellés nomment les zones, la couleur ne porte pas seule le sens.
public struct LoadGauge: View {
    private static let barHeight: CGFloat = 10
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
        GeometryReader { proxy in
            let radius = Self.markerDiameter / 2
            let center = min(max(proxy.size.width * LoadGaugeGeometry.fraction(ratio: ratio), radius), proxy.size.width - radius)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(zones)
                    .frame(height: Self.barHeight)
                Circle()
                    .fill(PulsePalette.text)
                    .overlay(Circle().strokeBorder(PulsePalette.background, lineWidth: Self.markerBorder))
                    .frame(width: Self.markerDiameter, height: Self.markerDiameter)
                    .offset(x: center - radius)
            }
            .frame(maxHeight: .infinity)
        }
        .frame(height: Self.markerDiameter)
    }

    /// `linear-gradient(90deg, run 0 20%, ok 20% 60%, warn 60% 78%, bad 78%)` : des changements de couleur nets.
    private var zones: LinearGradient {
        let colors = [PulsePalette.run, PulsePalette.ok, PulsePalette.warn, PulsePalette.bad]
        let bounds = LoadGaugeGeometry.zoneBounds
        let stops = colors.indices.flatMap { index in
            [
                Gradient.Stop(color: colors[index], location: bounds[index]),
                Gradient.Stop(color: colors[index], location: bounds[index + 1])
            ]
        }
        return LinearGradient(stops: stops, startPoint: .leading, endPoint: .trailing)
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
