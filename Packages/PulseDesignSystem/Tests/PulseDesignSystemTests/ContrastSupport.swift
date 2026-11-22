import Foundation

@testable import PulseDesignSystem

/// Contraste WCAG partagé par les tests de palette : luminance relative, composition d'une couleur translucide sur un fond,
/// rapport de contraste.
enum Contrast {
    private struct Channels {
        let red: Double
        let green: Double
        let blue: Double
    }

    private static func luminance(_ color: Channels) -> Double {
        func channel(_ value: Double) -> Double {
            value <= 0.03928 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(color.red) + 0.7152 * channel(color.green) + 0.0722 * channel(color.blue)
    }

    /// `color` posée sur `backdrop` : l'opacité de `color` mélange les deux, le résultat est opaque.
    private static func composite(_ color: PulseRGBA, over backdrop: Channels) -> Channels {
        let alpha = color.opacity
        return Channels(
            red: color.red * alpha + backdrop.red * (1 - alpha),
            green: color.green * alpha + backdrop.green * (1 - alpha),
            blue: color.blue * alpha + backdrop.blue * (1 - alpha)
        )
    }

    /// Le rapport de contraste de `foreground` sur `background`. Une couleur translucide est d'abord posée sur `backdrop`
    /// (par défaut du noir pour un fond, le fond lui-même pour le texte) : par exemple un badge `opal` à 0,85 sur la page.
    static func ratio(_ foreground: PulseRGBA, on background: PulseRGBA, backdrop: PulseRGBA? = nil) -> Double {
        let base = backdrop.map { Channels(red: $0.red, green: $0.green, blue: $0.blue) } ?? Channels(red: 0, green: 0, blue: 0)
        let flatBackground = composite(background, over: base)
        let flatForeground = composite(foreground, over: flatBackground)
        let first = luminance(flatForeground)
        let second = luminance(flatBackground)
        return (max(first, second) + 0.05) / (min(first, second) + 0.05)
    }
}
