import PulseDomain
import SwiftUI

/// La dalle tramée : la carte du score. Une trame de points s'y imprime : encre noire sur papier en clair, argent sur noir en
/// sombre. `heat` (0…100, en général le score de récupération) règle son intensité : une trame presque effacée à 0, un grand
/// halo de points à 100. Sans `heat`, la dalle prend une intensité moyenne.
public struct OpalCard<Content: View>: View {
    private let heat: Double?
    private let content: Content
    @Environment(\.colorScheme) private var colorScheme

    public init(heat: Double? = nil, @ViewBuilder content: () -> Content) {
        self.heat = heat
        self.content = content()
    }

    public var body: some View {
        let temperature = Self.temperature(for: heat)
        content
            .foregroundStyle(PulsePalette.opalInk)
            .padding(PulseMetrics.spacing + 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background { HalftoneSlab(temperature: temperature, isDark: colorScheme == .dark) }
            .clipShape(shape)
            .overlay(shape.strokeBorder(LitEdge.gradient(strength: 1.6), lineWidth: 1))
            .shadow(color: PulsePalette.cardShadow, radius: 24, y: 10)
            .shadow(color: Color.white.opacity(colorScheme == .dark ? 0.1 * temperature : 0), radius: 34, y: 10)
            .accessibilityElement(children: .contain)
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: PulseMetrics.radiusHero, style: .continuous)
    }

    /// La lumière de la dalle, de 0 à 1 : le score ramené sur 1, 0,55 sans score ou s'il n'est pas fini.
    nonisolated static func temperature(for heat: Double?) -> Double {
        guard let heat, heat.isFinite else { return 0.55 }
        return min(max(heat, 0), 100) / 100
    }
}

/// Le fond de la dalle : la lumière tombe du coin haut droit et s'étend avec le score, sans jamais entrer au centre où se lit
/// le score ; un voile du fond de la dalle, en bas, garde les facteurs lisibles. En sombre, un reflet de lumière diffuse, très
/// bas, adoucit la trame ; sur le papier, l'encre se suffit.
private struct HalftoneSlab: View {
    let temperature: Double
    let isDark: Bool

    var body: some View {
        let strength = 0.3 + 0.7 * temperature
        let spread = 0.18 + 0.3 * temperature
        ZStack {
            PulsePalette.opal
            if isDark {
                RadialGradient(colors: [Color.white.opacity(0.14 * strength), .clear],
                               center: UnitPoint(x: 0.92, y: 0.04), startRadius: 0, endRadius: 360)
            }
            HalftoneField(spacing: 6.5, maxRadius: 2.4, color: PulsePalette.ink.opacity(isDark ? 0.62 : 0.66)) { point in
                let light = strength * Halftone.glow(at: point, center: CGPoint(x: 0.97, y: 0.0), spread: spread)
                let clearing = 1 - 0.95 * Halftone.glow(at: point, center: CGPoint(x: 0.5, y: 0.42), spread: 0.2)
                return light * clearing - 0.04
            }
            LinearGradient(colors: [.clear, PulsePalette.opal.opacity(0.7)], startPoint: .center, endPoint: .bottom)
        }
    }
}

/// Carte obsidienne : un graphite mat (une feuille blanche en clair), cernée d'un filet. Pour tout le reste : elle reste calme
/// pour laisser l'intensité à la dalle du score et au bouton principal.
public struct ObsidianCard<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        content
            .foregroundStyle(PulsePalette.text)
            .padding(PulseMetrics.spacing)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(PulsePalette.surface, in: shape)
            .overlay(shape.strokeBorder(LitEdge.gradient(), lineWidth: 1))
            .shadow(color: PulsePalette.cardShadow, radius: 16, y: 6)
            .accessibilityElement(children: .contain)
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: PulseMetrics.radius, style: .continuous)
    }
}

/// Le filet des cartes et des boutons, dans l'encre de l'apparence : net en haut, plus léger en bas, comme une arête éclairée
/// par le dessus.
public enum LitEdge {
    public static func gradient(strength: Double = 1) -> LinearGradient {
        let ink = PulsePalette.ink
        return LinearGradient(
            colors: [ink.opacity(0.14 * strength), ink.opacity(0.07 * strength), ink.opacity(0.05 * strength)],
            startPoint: .top, endPoint: .bottom
        )
    }
}

#Preview {
    VStack(spacing: 10) {
        OpalCard(heat: 88) {
            Text("Dalle claire").font(PulseFont.title(.headline))
            Text("88 sur 100").font(.footnote).foregroundStyle(PulsePalette.opalMuted)
        }
        OpalCard(heat: 22) {
            Text("Dalle sombre").font(PulseFont.title(.headline))
        }
        ObsidianCard {
            Text("Carte obsidienne").font(.headline)
        }
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(PulsePalette.background)
}
