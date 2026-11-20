import SwiftUI

/// Écran provisoire d'un onglet dont le contenu arrive avec un jalon ultérieur.
public struct ComingSoonView: View {
    private let title: String
    private let milestone: String

    public init(title: String, milestone: String) {
        self.title = title
        self.milestone = milestone
    }

    public var body: some View {
        VStack(spacing: 10) {
            // Une sphère en trame, éclairée en haut à gauche.
            HalftoneField(spacing: 5.5, color: PulsePalette.text) { point in
                let distance = hypot(Double(point.x) - 0.5, Double(point.y) - 0.5)
                guard distance < 0.5 else { return 0 }
                return 0.08 + 0.92 * Halftone.glow(at: point, center: CGPoint(x: 0.36, y: 0.32), spread: 0.3)
            }
            .frame(width: 104, height: 104)
            .padding(.bottom, 6)
            Text(milestone)
                .pulseEyebrow()
            Text(title)
                .font(PulseFont.title(.title2))
                .foregroundStyle(PulsePalette.text)
            Text(String(localized: "Bientôt disponible, prévu au jalon \(milestone).", bundle: .module))
                .font(.subheadline)
                .foregroundStyle(PulsePalette.text2)
                .multilineTextAlignment(.center)
        }
        .padding(PulseMetrics.spacing)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    ComingSoonView(title: "Séances", milestone: "M4")
        .background(PulsePalette.background)
}
