import PulseDomain
import SwiftUI

/// Couleurs d'ambiance : l'accent suit le thème du profil.
public struct AccentPalette: Equatable, Sendable {
    public let accent: PulseRGBA
    public let accent2: PulseRGBA
    public let accentInk: PulseRGBA
    public let softOpacity: Double

    public init(accent: PulseRGBA, accent2: PulseRGBA, accentInk: PulseRGBA, softOpacity: Double) {
        self.accent = accent
        self.accent2 = accent2
        self.accentInk = accentInk
        self.softOpacity = softOpacity
    }

    /// L'accent à faible opacité, pour les fonds de pastille (`--accent-soft`).
    public var soft: Color { Color(accent).opacity(softOpacity) }
}

/// Jetons de couleur du thème sombre, repris du `:root` de `maquette.html` (spec M3 §6.1).
public enum PulsePalette {
    // Fonds
    public static let pageRGBA = PulseRGBA(hex: 0x050608)
    public static let backgroundRGBA = PulseRGBA(hex: 0x0B0C10)
    public static let surfaceRGBA = PulseRGBA(hex: 0x13151C)
    public static let surface2RGBA = PulseRGBA(hex: 0x1B1E27)
    public static let lineRGBA = PulseRGBA(hex: 0xFFFFFF, opacity: 0.08)
    public static let page = Color(pageRGBA)
    public static let background = Color(backgroundRGBA)
    public static let surface = Color(surfaceRGBA)
    public static let surface2 = Color(surface2RGBA)
    public static let line = Color(lineRGBA)

    // Texte
    public static let textRGBA = PulseRGBA(hex: 0xF4F5F7)
    public static let text2RGBA = PulseRGBA(hex: 0xA3A9B7)
    public static let mutedRGBA = PulseRGBA(hex: 0x6C7383)
    public static let text = Color(textRGBA)
    public static let text2 = Color(text2RGBA)
    public static let muted = Color(mutedRGBA)

    // Opale
    public static let opalRGBA = PulseRGBA(hex: 0xFFFFFF)
    public static let opalInkRGBA = PulseRGBA(hex: 0x0A0B0F)
    public static let opalMutedRGBA = PulseRGBA(hex: 0x6B7280)
    public static let opalLineRGBA = PulseRGBA(hex: 0x0A0B0F, opacity: 0.08)
    public static let opalOKRGBA = PulseRGBA(hex: 0x047857)
    public static let opalWarnRGBA = PulseRGBA(hex: 0xB45309)
    public static let opalBadRGBA = PulseRGBA(hex: 0xDC2626)
    public static let opal = Color(opalRGBA)
    public static let opalInk = Color(opalInkRGBA)
    public static let opalMuted = Color(opalMutedRGBA)
    public static let opalLine = Color(opalLineRGBA)
    public static let opalOK = Color(opalOKRGBA)
    public static let opalWarn = Color(opalWarnRGBA)
    public static let opalBad = Color(opalBadRGBA)

    // États
    public static let okRGBA = PulseRGBA(hex: 0x10B981)
    public static let warnRGBA = PulseRGBA(hex: 0xF59E0B)
    public static let badRGBA = PulseRGBA(hex: 0xEF4444)
    public static let runRGBA = PulseRGBA(hex: 0x06B6D4)
    public static let goldRGBA = PulseRGBA(hex: 0xF5C518)
    public static let ok = Color(okRGBA)
    public static let warn = Color(warnRGBA)
    public static let bad = Color(badRGBA)
    public static let run = Color(runRGBA)
    public static let gold = Color(goldRGBA)
    public static let okSoft = ok.opacity(0.16)
    public static let warnSoft = warn.opacity(0.16)
    public static let badSoft = bad.opacity(0.16)
    public static let runSoft = run.opacity(0.16)
    public static let goldSoft = gold.opacity(0.16)

    // Carte musculaire
    public static let muscleBodyRGBA = PulseRGBA(hex: 0x262932)
    public static let muscleOffRGBA = PulseRGBA(hex: 0x3A3F4B)
    public static let muscleBody = Color(muscleBodyRGBA)
    public static let muscleOff = Color(muscleOffRGBA)

    /// Les couleurs d'ambiance du thème : ambre (défaut) ou améthyste.
    public static func accent(for theme: Theme) -> AccentPalette {
        switch theme {
        case .amber:
            AccentPalette(
                accent: PulseRGBA(hex: 0xF59E0B), accent2: PulseRGBA(hex: 0xEA580C),
                accentInk: PulseRGBA(hex: 0x1A1206), softOpacity: 0.16
            )
        case .amethyst:
            AccentPalette(
                accent: PulseRGBA(hex: 0xA855F7), accent2: PulseRGBA(hex: 0x6366F1),
                accentInk: PulseRGBA(hex: 0xFFFFFF), softOpacity: 0.18
            )
        }
    }
}
