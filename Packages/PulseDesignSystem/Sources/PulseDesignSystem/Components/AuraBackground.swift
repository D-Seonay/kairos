import PulseDomain
import SwiftUI

/// L'aura du haut d'écran (`--aura`) : dégradé elliptique accent puis accent2, en haut à droite.
/// À poser derrière le contenu, sur le fond `background`.
public struct AuraBackground: View {
    @Environment(\.pulseTheme) private var theme

    public init() {}

    public var body: some View {
        let palette = PulsePalette.accent(for: theme)
        EllipticalGradient(
            stops: [
                .init(color: Color(palette.accent).opacity(0.55), location: 0),
                .init(color: Color(palette.accent2).opacity(0.28), location: 0.45),
                .init(color: .clear, location: 0.8)
            ],
            center: UnitPoint(x: 0.7, y: 0),
            startRadiusFraction: 0,
            endRadiusFraction: 0.6
        )
        .frame(height: 360)
        .blur(radius: 24)
        .opacity(0.9)
        .frame(maxHeight: .infinity, alignment: .top)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

#Preview {
    ZStack {
        PulsePalette.background
        AuraBackground()
    }
    .ignoresSafeArea()
}
