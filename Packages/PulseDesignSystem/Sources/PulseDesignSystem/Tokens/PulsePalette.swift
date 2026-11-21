import PulseDomain
import SwiftUI

/// Couleurs d'ambiance : l'accent suit le thème du profil.
/// Chaque couleur a deux tirages : en clair l'accent est une encre presque noire, en sombre un blanc.
public struct AccentPalette: Equatable, Sendable {
    public let accent: PulseTone
    public let accent2: PulseTone
    public let accentInk: PulseTone
    public let softOpacity: Double

    public init(accent: PulseTone, accent2: PulseTone, accentInk: PulseTone, softOpacity: Double) {
        self.accent = accent
        self.accent2 = accent2
        self.accentInk = accentInk
        self.softOpacity = softOpacity
    }

    /// L'accent à faible opacité, pour les fonds de pastille (`--accent-soft`).
    public var soft: Color { Color(accent).opacity(softOpacity) }
}

/// Jetons de couleur de la direction « Argentique » : un tirage noir et blanc, en deux apparences. En clair, un papier chaud et
/// une encre noire, la trame imprimée comme dans un journal ; en sombre, un noir OLED et une encre blanche. La donnée s'exprime
/// en contraste (plus c'est encré, mieux c'est) et en trame de points. Une seule couleur dans toute l'app, le « signal »,
/// réservée à ce qui demande d'agir : surmenage, risque, erreur.
///
/// Les `…RGBA` sont les tirages sombres, les `…LightRGBA` les tirages clairs ; les `Color` suivent l'apparence.
public enum PulsePalette {
    /// L'encre des filets, des trames et des repères : noire sur le papier, blanche sur le noir.
    public static let ink = Color(light: PulseRGBA(hex: 0x0B0B0A), dark: PulseRGBA(hex: 0xFFFFFF))
    /// L'ombre portée des cartes : une ombre douce sur le papier, rien sur le noir.
    public static let cardShadow = Color(light: PulseRGBA(hex: 0x2A2418, opacity: 0.07), dark: PulseRGBA(hex: 0x000000, opacity: 0))

    // Fonds
    public static let pageRGBA = PulseRGBA(hex: 0x000000)
    public static let pageLightRGBA = PulseRGBA(hex: 0xEFECE5)
    public static let backgroundRGBA = PulseRGBA(hex: 0x000000)
    public static let backgroundLightRGBA = PulseRGBA(hex: 0xEFECE5)
    public static let surfaceRGBA = PulseRGBA(hex: 0x0E0E0F)
    public static let surfaceLightRGBA = PulseRGBA(hex: 0xFBFAF7)
    public static let surface2RGBA = PulseRGBA(hex: 0x1A1A1C)
    public static let surface2LightRGBA = PulseRGBA(hex: 0xE6E2DA)
    public static let lineRGBA = PulseRGBA(hex: 0xFFFFFF, opacity: 0.09)
    public static let lineLightRGBA = PulseRGBA(hex: 0x0B0B0A, opacity: 0.1)
    /// Le noir pur de l'écran de séance (spec M4 §14.2), dans les deux apparences : la séance reste toujours sombre.
    public static let liveBackgroundRGBA = PulseRGBA(hex: 0x000000)
    public static let page = Color(light: pageLightRGBA, dark: pageRGBA)
    public static let background = Color(light: backgroundLightRGBA, dark: backgroundRGBA)
    public static let surface = Color(light: surfaceLightRGBA, dark: surfaceRGBA)
    public static let surface2 = Color(light: surface2LightRGBA, dark: surface2RGBA)
    public static let line = Color(light: lineLightRGBA, dark: lineRGBA)
    public static let liveBackground = Color(liveBackgroundRGBA)

    // Texte
    public static let textRGBA = PulseRGBA(hex: 0xF4F4F1)
    public static let textLightRGBA = PulseRGBA(hex: 0x111110)
    public static let text2RGBA = PulseRGBA(hex: 0xA2A2A0)
    public static let text2LightRGBA = PulseRGBA(hex: 0x57554F)
    public static let mutedRGBA = PulseRGBA(hex: 0x6E6E6C)
    public static let mutedLightRGBA = PulseRGBA(hex: 0x86837C)
    public static let text = Color(light: textLightRGBA, dark: textRGBA)
    public static let text2 = Color(light: text2LightRGBA, dark: text2RGBA)
    public static let muted = Color(light: mutedLightRGBA, dark: mutedRGBA)

    // Opale : la dalle tramée du score. Une trame de points s'y imprime avec le score : encre noire sur papier en clair,
    // points d'argent sur noir en sombre.
    public static let opalRGBA = PulseRGBA(hex: 0x0A0A0B)
    public static let opalLightRGBA = PulseRGBA(hex: 0xFBFAF7)
    public static let opalInkRGBA = PulseRGBA(hex: 0xFFFFFF)
    public static let opalInkLightRGBA = PulseRGBA(hex: 0x0B0B0A)
    public static let opalMutedRGBA = PulseRGBA(hex: 0xFFFFFF, opacity: 0.6)
    public static let opalMutedLightRGBA = PulseRGBA(hex: 0x0B0B0A, opacity: 0.58)
    public static let opalLineRGBA = PulseRGBA(hex: 0xFFFFFF, opacity: 0.12)
    public static let opalLineLightRGBA = PulseRGBA(hex: 0x0B0B0A, opacity: 0.12)
    public static let opalOKRGBA = PulseRGBA(hex: 0xFFFFFF)
    public static let opalOKLightRGBA = PulseRGBA(hex: 0x111110)
    public static let opalWarnRGBA = PulseRGBA(hex: 0xC2C2BF)
    public static let opalWarnLightRGBA = PulseRGBA(hex: 0x6D6A64)
    public static let opalBadRGBA = PulseRGBA(hex: 0xFF5B3D)
    public static let opalBadLightRGBA = PulseRGBA(hex: 0xD9391A)
    public static let opal = Color(light: opalLightRGBA, dark: opalRGBA)
    public static let opalInk = Color(light: opalInkLightRGBA, dark: opalInkRGBA)
    public static let opalMuted = Color(light: opalMutedLightRGBA, dark: opalMutedRGBA)
    public static let opalLine = Color(light: opalLineLightRGBA, dark: opalLineRGBA)
    public static let opalOK = Color(light: opalOKLightRGBA, dark: opalOKRGBA)
    public static let opalWarn = Color(light: opalWarnLightRGBA, dark: opalWarnRGBA)
    public static let opalBad = Color(light: opalBadLightRGBA, dark: opalBadRGBA)

    // États : le bon est l'encre pleine, l'attention est grise, le mauvais est le signal.
    public static let okRGBA = PulseRGBA(hex: 0xF4F4F1)
    public static let okLightRGBA = PulseRGBA(hex: 0x111110)
    public static let warnRGBA = PulseRGBA(hex: 0xA8A8A5)
    public static let warnLightRGBA = PulseRGBA(hex: 0x77746D)
    public static let badRGBA = PulseRGBA(hex: 0xFF4F2E)
    public static let badLightRGBA = PulseRGBA(hex: 0xD9391A)
    /// La course : un gris froid, pour la distinguer de la musculation sans sortir du noir et blanc.
    public static let runRGBA = PulseRGBA(hex: 0xC6CCD4)
    public static let runLightRGBA = PulseRGBA(hex: 0x4E5764)
    /// Les records : un champagne, à peine chaud (un bronze sombre sur le papier).
    public static let goldRGBA = PulseRGBA(hex: 0xEDE3CC)
    public static let goldLightRGBA = PulseRGBA(hex: 0x8A743F)
    public static let ok = Color(light: okLightRGBA, dark: okRGBA)
    public static let warn = Color(light: warnLightRGBA, dark: warnRGBA)
    public static let bad = Color(light: badLightRGBA, dark: badRGBA)
    public static let run = Color(light: runLightRGBA, dark: runRGBA)
    public static let gold = Color(light: goldLightRGBA, dark: goldRGBA)
    public static let okSoft = ok.opacity(0.1)
    public static let warnSoft = warn.opacity(0.12)
    public static let badSoft = bad.opacity(0.16)
    public static let runSoft = run.opacity(0.12)
    public static let goldSoft = gold.opacity(0.12)

    /// La seule couleur de l'app : ce qui demande d'agir. Même teinte que `bad`.
    public static let signal = bad

    // Carte musculaire
    public static let muscleBodyRGBA = PulseRGBA(hex: 0x19191B)
    public static let muscleBodyLightRGBA = PulseRGBA(hex: 0xE3DFD7)
    public static let muscleOffRGBA = PulseRGBA(hex: 0x2E2E31)
    public static let muscleOffLightRGBA = PulseRGBA(hex: 0xCFCAC0)
    public static let muscleBody = Color(light: muscleBodyLightRGBA, dark: muscleBodyRGBA)
    public static let muscleOff = Color(light: muscleOffLightRGBA, dark: muscleOffRGBA)

    /// Les couleurs d'ambiance du thème. « Ivoire » (l'ancien ambre) est chaud : encre brun-noir sur papier, blanc cassé sur
    /// noir. « Acier » (l'ancienne améthyste) est froid : encre bleu-noir, blanc bleuté. `accent2` est le gris où le dégradé
    /// finit, l'encre est ce qui s'écrit sur l'accent.
    public static func accent(for theme: Theme) -> AccentPalette {
        switch theme {
        case .amber:
            AccentPalette(
                accent: PulseTone(light: PulseRGBA(hex: 0x17140F), dark: PulseRGBA(hex: 0xF3EEE5)),
                accent2: PulseTone(light: PulseRGBA(hex: 0x4D473E), dark: PulseRGBA(hex: 0xB9B1A4)),
                accentInk: PulseTone(light: PulseRGBA(hex: 0xF7F3EC), dark: PulseRGBA(hex: 0x0A0A0A)),
                softOpacity: 0.1
            )
        case .amethyst:
            AccentPalette(
                accent: PulseTone(light: PulseRGBA(hex: 0x0F141B), dark: PulseRGBA(hex: 0xE9EEF4)),
                accent2: PulseTone(light: PulseRGBA(hex: 0x434B56), dark: PulseRGBA(hex: 0x9BA6B3)),
                accentInk: PulseTone(light: PulseRGBA(hex: 0xF2F5F8), dark: PulseRGBA(hex: 0x0A0A0A)),
                softOpacity: 0.1
            )
        }
    }
}

public extension AccentPalette {
    /// Le dégradé du thème, de `accent` à `accent2` : un reflet d'encre ou de métal, pour ce qui est actif.
    func gradient(startPoint: UnitPoint = .leading, endPoint: UnitPoint = .trailing) -> LinearGradient {
        LinearGradient(colors: [Color(accent), Color(accent2)], startPoint: startPoint, endPoint: endPoint)
    }
}

public extension Theme {
    /// Le nom de l'ambiance dans les réglages : « Ivoire » (`.amber`) ou « Acier » (`.amethyst`).
    var title: String {
        switch self {
        case .amber: String(localized: "Ivoire", bundle: .module)
        case .amethyst: String(localized: "Acier", bundle: .module)
        }
    }
}
