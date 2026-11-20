import SwiftUI

/// La typographie « Argentique » : SF Pro pour lire, SF Mono pour étiqueter. Les grands chiffres sont fins, comme gravés sur un
/// cadran ; les valeurs des cartes sont moyennes ; les étiquettes sont en capitales mono espacées, comme sur un instrument.
public enum PulseFont {
    /// Un grand chiffre : le score, un minuteur, un total. Fin, chiffres à chasse fixe.
    public static func score(size: CGFloat) -> Font {
        .system(size: size, weight: .thin).monospacedDigit()
    }

    /// Une valeur dans une carte (« 7 h 12 », « 62 ms ») : chiffres à chasse fixe. Suit la taille du texte.
    public static func value(_ style: Font.TextStyle = .title2, weight: Font.Weight = .medium) -> Font {
        .system(style, weight: weight).monospacedDigit()
    }

    /// Le titre d'un écran ou d'une carte maîtresse. Suit la taille du texte.
    public static func title(_ style: Font.TextStyle = .title, weight: Font.Weight = .bold) -> Font {
        .system(style, weight: weight)
    }

    /// Une étiquette d'instrument (« RÉCUPÉRATION », « 7 JOURS ») : mono, petite. À poser avec `pulseEyebrow()`.
    public static let eyebrow: Font = .system(.caption2, design: .monospaced, weight: .medium)

    /// Le libellé d'un bouton.
    public static let button: Font = .system(.body, weight: .semibold)
}

public extension View {
    /// Une étiquette d'instrument : mono, capitales, espacée, grise par défaut.
    func pulseEyebrow(_ color: Color = PulsePalette.muted) -> some View {
        font(PulseFont.eyebrow)
            .textCase(.uppercase)
            .tracking(1.4)
            .foregroundStyle(color)
    }
}
