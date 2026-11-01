import PulseDomain
import SwiftUI

/// Bouton principal : plein, accent, texte `accentInk`, pleine largeur.
public struct PrimaryButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        PulseButtonBody(configuration: configuration, kind: .primary)
    }
}

/// Bouton secondaire : surface sombre, bord `line`.
public struct SecondaryButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        PulseButtonBody(configuration: configuration, kind: .secondary)
    }
}

/// Bouton lien : texte accent, sans fond.
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

    var body: some View {
        let palette = PulsePalette.accent(for: theme)
        configuration.label
            .font(.system(.body, weight: kind == .link ? .semibold : .bold))
            .foregroundStyle(foreground(palette))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: PulseMetrics.minButtonHeight)
            .background(background(palette), in: shape)
            .overlay { if kind == .secondary { shape.strokeBorder(PulsePalette.line) } }
            .contentShape(shape)
            .opacity(isEnabled ? (configuration.isPressed ? 0.7 : 1) : 0.4)
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: PulseMetrics.radiusSmall, style: .continuous)
    }

    private func foreground(_ palette: AccentPalette) -> Color {
        switch kind {
        case .primary: Color(palette.accentInk)
        case .secondary: PulsePalette.text
        case .link: Color(palette.accent)
        }
    }

    private func background(_ palette: AccentPalette) -> Color {
        switch kind {
        case .primary: Color(palette.accent)
        case .secondary: PulsePalette.surface2
        case .link: .clear
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
