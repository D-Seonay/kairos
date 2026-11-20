import PulseDomain
import SwiftUI

/// Bouton principal : une capsule pleine de l'accent du thème (noire sur le papier, blanche sur le noir), avec un reflet en
/// haut. Pleine largeur.
public struct PrimaryButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        PulseButtonBody(configuration: configuration, kind: .primary)
    }
}

/// Bouton secondaire : une capsule vide cernée d'un filet.
public struct SecondaryButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        PulseButtonBody(configuration: configuration, kind: .secondary)
    }
}

/// Bouton lien : texte de l'accent du thème, sans fond.
public struct LinkButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        PulseButtonBody(configuration: configuration, kind: .link)
    }
}

private struct PulseButtonBody: View {
    enum Kind { case primary, secondary, link }

    let configuration: ButtonStyleConfiguration
    let kind: Kind
    @Environment(\.pulseTheme) private var theme
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let palette = PulsePalette.accent(for: theme)
        let pressed = configuration.isPressed
        configuration.label
            .font(kind == .link ? .system(.body, weight: .semibold) : PulseFont.button)
            .foregroundStyle(foreground(palette))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, minHeight: PulseMetrics.minButtonHeight)
            .background { background(palette) }
            .contentShape(Capsule())
            .scaleEffect(pressed && kind != .link ? 0.97 : 1)
            .opacity(isEnabled ? (pressed && kind == .link ? 0.6 : 1) : 0.35)
            .animation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.6), value: pressed)
    }

    private func foreground(_ palette: AccentPalette) -> Color {
        switch kind {
        case .primary: Color(palette.accentInk)
        case .secondary: PulsePalette.text
        case .link: Color(palette.accent)
        }
    }

    @ViewBuilder
    private func background(_ palette: AccentPalette) -> some View {
        switch kind {
        case .primary:
            Capsule()
                .fill(Color(palette.accent))
                // Un reflet en haut et une ombre de gris en bas : le bouton a le volume d'une pièce polie. Sur le noir d'encre du
                // mode clair, le reflet reste discret.
                .overlay(Capsule().fill(LinearGradient(
                    colors: [.white.opacity(colorScheme == .dark ? 0.7 : 0.16), .clear, Color(palette.accent2).opacity(0.35)],
                    startPoint: .top, endPoint: .bottom)))
                .shadow(color: Color(palette.accent).opacity(isEnabled ? 0.18 : 0), radius: 18, y: 6)
        case .secondary:
            Capsule()
                .fill(PulsePalette.surface.opacity(0.6))
                .overlay(Capsule().strokeBorder(PulsePalette.ink.opacity(0.2), lineWidth: 1))
        case .link:
            Color.clear
        }
    }
}

#Preview {
    VStack(spacing: 10) {
        Button("Continuer") {}.buttonStyle(PrimaryButtonStyle())
        Button("Plus tard") {}.buttonStyle(SecondaryButtonStyle())
        Button("Continuer sans montre") {}.buttonStyle(LinkButtonStyle())
        Button("Désactivé") {}.buttonStyle(PrimaryButtonStyle()).disabled(true)
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(PulsePalette.background)
}
