import PulseDomain
import SwiftUI

/// Le haut d'écran « Argentique » : une trame de points éclairée par un halo qui dérive lentement, comme la lumière d'un
/// agrandisseur sur un tirage ; sur le papier, la trame est imprimée à l'encre. À poser derrière le contenu, sur le fond
/// `background`. `intensity` (0…1) la rend plus discrète sur les écrans secondaires. Elle reste immobile quand « Réduire les
/// animations » est activé.
public struct AuraBackground: View {
    private let intensity: Double
    @Environment(\.pulseTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @State private var phase = 0.0

    public init(intensity: Double = 1) {
        self.intensity = min(max(intensity, 0), 1)
    }

    public var body: some View {
        let tint = Color(PulsePalette.accent(for: theme).accent)
        ZStack(alignment: .top) {
            // Le halo : une lueur très basse qui glisse de droite à gauche, blanche sur le noir, une ombre légère sur le papier.
            RadialGradient(colors: [tint.opacity(colorScheme == .dark ? 0.16 : 0.05), tint.opacity(0.02), .clear],
                           center: UnitPoint(x: 0.85 - 0.35 * phase, y: 0.05), startRadius: 0, endRadius: 320)
            DotGrid(tint: tint.opacity(colorScheme == .dark ? 0.38 : 0.2))
        }
        .frame(height: 420)
        .mask(LinearGradient(colors: [.black, .black.opacity(0.5), .clear], startPoint: .top, endPoint: .bottom))
        .opacity(intensity)
        .frame(maxHeight: .infinity, alignment: .top)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 14).repeatForever(autoreverses: true)) { phase = 1 }
        }
    }
}

/// La trame du haut d'écran : des points minuscules, plus gros sous le halo. Elle ne bouge pas, seul le halo dérive : la
/// redessiner à chaque image coûterait de la batterie pour un mouvement à peine visible.
private struct DotGrid: View {
    let tint: Color

    var body: some View {
        HalftoneField(spacing: 11, maxRadius: 1.6, color: tint) { point in
            0.12 + 0.88 * Halftone.glow(at: point, center: CGPoint(x: 0.7, y: 0.05), spread: 0.45)
        }
    }
}

public extension View {
    /// Le fond d'un écran principal : le noir, et la trame éclairée en haut. `aura` (0…1) règle son intensité, 0 l'éteint.
    func pulseScreenBackground(aura: Double = 1) -> some View {
        background {
            ZStack {
                PulsePalette.background
                if aura > 0 {
                    AuraBackground(intensity: aura)
                }
            }
            .ignoresSafeArea()
        }
    }
}

#Preview {
    ZStack {
        PulsePalette.background
        AuraBackground()
    }
    .ignoresSafeArea()
}
