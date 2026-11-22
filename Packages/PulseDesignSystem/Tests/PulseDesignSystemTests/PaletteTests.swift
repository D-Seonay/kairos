import Foundation
import PulseDomain
import SwiftUI
import Testing

@testable import PulseDesignSystem

@Test func hexBecomesComponents() {
    let amber = PulseRGBA(hex: 0xF59E0B)
    #expect(amber.red == 245.0 / 255 && amber.green == 158.0 / 255 && amber.blue == 11.0 / 255 && amber.opacity == 1)
}

@Test func hexKeepsTheGivenOpacity() {
    #expect(PulseRGBA(hex: 0xFFFFFF, opacity: 0.08).opacity == 0.08)
}

@Test func accentFollowsTheme() {
    let ivory = PulsePalette.accent(for: .amber)
    #expect(ivory.accent == PulseTone(light: PulseRGBA(hex: 0x17140F), dark: PulseRGBA(hex: 0xF3EEE5)))
    #expect(ivory.accent2 == PulseTone(light: PulseRGBA(hex: 0x4D473E), dark: PulseRGBA(hex: 0xB9B1A4)))
    #expect(ivory.accentInk == PulseTone(light: PulseRGBA(hex: 0xF7F3EC), dark: PulseRGBA(hex: 0x0A0A0A)))
    #expect(ivory.softOpacity == 0.1)

    let steel = PulsePalette.accent(for: .amethyst)
    #expect(steel.accent == PulseTone(light: PulseRGBA(hex: 0x0F141B), dark: PulseRGBA(hex: 0xE9EEF4)))
    #expect(steel.accent2 == PulseTone(light: PulseRGBA(hex: 0x434B56), dark: PulseRGBA(hex: 0x9BA6B3)))
    #expect(steel.accentInk == PulseTone(light: PulseRGBA(hex: 0xF2F5F8), dark: PulseRGBA(hex: 0x0A0A0A)))
    #expect(steel.softOpacity == 0.1)
}

@Test func themeTitlesAreIvoryAndSteel() {
    #expect(Theme.amber.title == "Ivoire")
    #expect(Theme.amethyst.title == "Acier")
}

@Test func darkTokensFollowTheSilverDirection() {
    #expect(PulsePalette.backgroundRGBA == PulseRGBA(hex: 0x000000))
    #expect(PulsePalette.surfaceRGBA == PulseRGBA(hex: 0x0E0E0F))
    #expect(PulsePalette.opalRGBA == PulseRGBA(hex: 0x0A0A0B))
    #expect(PulsePalette.opalInkRGBA == PulseRGBA(hex: 0xFFFFFF))
    #expect(PulsePalette.muscleBodyRGBA == PulseRGBA(hex: 0x19191B))
    #expect(PulsePalette.muscleOffRGBA == PulseRGBA(hex: 0x2E2E31))
    #expect(PulsePalette.lineRGBA.opacity == 0.09)
}

@Test func lightTokensArePaperAndInk() {
    #expect(PulsePalette.backgroundLightRGBA == PulseRGBA(hex: 0xEFECE5))
    #expect(PulsePalette.surfaceLightRGBA == PulseRGBA(hex: 0xFBFAF7))
    #expect(PulsePalette.textLightRGBA == PulseRGBA(hex: 0x111110))
    #expect(PulsePalette.opalInkLightRGBA == PulseRGBA(hex: 0x0B0B0A))
    #expect(PulsePalette.lineLightRGBA.opacity == 0.1)
}

private struct ContrastPair: CustomStringConvertible {
    let name: String
    let foreground: PulseRGBA
    let background: PulseRGBA
    let backdrop: PulseRGBA?
    let minimum: Double

    init(_ name: String, _ foreground: PulseRGBA, on background: PulseRGBA, backdrop: PulseRGBA? = nil, minimum: Double = 4.5) {
        self.name = name
        self.foreground = foreground
        self.background = background
        self.backdrop = backdrop
        self.minimum = minimum
    }

    var ratio: Double { Contrast.ratio(foreground, on: background, backdrop: backdrop) }
    var description: String { "\(name) \(ratio) < \(minimum)" }
}

/// Le texte reste lisible sur le papier : audit A §3, chaque paire du thème clair. 4,5:1 pour le texte, 3:1 pour les grands
/// chiffres et les éléments graphiques porteurs d'information.
@Test func lightPairsMeetWCAGAA() {
    let page = PulsePalette.backgroundLightRGBA, surface = PulsePalette.surfaceLightRGBA, surface2 = PulsePalette.surface2LightRGBA
    func pairs(_ name: String, _ text: PulseRGBA, on backgrounds: [(String, PulseRGBA)]) -> [ContrastPair] {
        backgrounds.map { ContrastPair("\(name) on \($0.0)", text, on: $0.1) }
    }
    let all: [(String, PulseRGBA)] = [("background", page), ("surface", surface), ("surface2", surface2)]
    // `muted` et `warn` ne se posent jamais sur `surface2` en texte (audit A §1) : leur ratio y est de 4,50 et 4,17.
    let flat: [(String, PulseRGBA)] = [("background", page), ("surface", surface)]
    var pairs = pairs("text", PulsePalette.textLightRGBA, on: all) + pairs("text2", PulsePalette.text2LightRGBA, on: all)
        + pairs("ok", PulsePalette.okLightRGBA, on: all) + pairs("run", PulsePalette.runLightRGBA, on: all)
        + pairs("bad", PulsePalette.badLightRGBA, on: all) + pairs("gold", PulsePalette.goldLightRGBA, on: all)
        + pairs("muted", PulsePalette.mutedLightRGBA, on: flat) + pairs("warn", PulsePalette.warnLightRGBA, on: flat)
    // La dalle opale et le badge de catégorie (opale à 0,85 sur la page).
    let opal = PulsePalette.opalLightRGBA
    let badge = PulseRGBA(hex: 0xFBFAF7, opacity: 0.85)
    pairs += [
        ContrastPair("opalInk on opal", PulsePalette.opalInkLightRGBA, on: opal),
        ContrastPair("opalMuted on opal", PulsePalette.opalMutedLightRGBA, on: opal),
        ContrastPair("opalOK on opal", PulsePalette.opalOKLightRGBA, on: opal),
        ContrastPair("opalWarn on opal", PulsePalette.opalWarnLightRGBA, on: opal),
        ContrastPair("opalBad on opal", PulsePalette.opalBadLightRGBA, on: opal),
        ContrastPair("opalBad on badge", PulsePalette.opalBadLightRGBA, on: badge, backdrop: PulsePalette.backgroundLightRGBA),
        ContrastPair("text on badge", PulsePalette.textLightRGBA, on: badge, backdrop: PulsePalette.backgroundLightRGBA),
        ContrastPair("page on ink", PulsePalette.pageLightRGBA, on: PulseRGBA(hex: 0x0B0B0A))
    ]
    // Un texte posé sur un fond `…Soft` (posé lui-même sur la surface). Seuls `okSoft` et `runSoft` portent du texte : `warnSoft`,
    // `badSoft` et `goldSoft` restent des fonds décoratifs (4,43, 4,34 et 4,2:1), à ne pas couvrir de texte.
    let softs: [(String, PulseRGBA)] = [("ok", PulsePalette.okLightRGBA), ("run", PulsePalette.runLightRGBA)]
    for (name, hue) in softs {
        let soft = PulseRGBA(hex: hex(hue), opacity: name == "ok" ? 0.1 : 0.12)
        pairs.append(ContrastPair("\(name) on \(name)Soft", hue, on: soft, backdrop: PulsePalette.surfaceLightRGBA))
    }
    // L'accent des deux thèmes : le bouton, son dégradé, le lien et les pastilles.
    for theme in [Theme.amber, .amethyst] {
        let palette = PulsePalette.accent(for: theme)
        let soft = PulseRGBA(hex: hex(palette.accent.light), opacity: palette.softOpacity)
        pairs += [
            ContrastPair("\(theme) accentInk on accent", palette.accentInk.light, on: palette.accent.light),
            ContrastPair("\(theme) accentInk on accent2", palette.accentInk.light, on: palette.accent2.light),
            ContrastPair("\(theme) accent on background", palette.accent.light, on: PulsePalette.backgroundLightRGBA),
            ContrastPair("\(theme) accent on surface", palette.accent.light, on: PulsePalette.surfaceLightRGBA),
            ContrastPair("\(theme) accent on accentSoft", palette.accent.light, on: soft, backdrop: PulsePalette.backgroundLightRGBA)
        ]
    }
    // Éléments graphiques porteurs d'information : 3:1.
    pairs += [
        ContrastPair("muted chevron on surface", PulsePalette.mutedLightRGBA, on: PulsePalette.surfaceLightRGBA, minimum: 3),
        ContrastPair("warn dots on background", PulsePalette.warnLightRGBA, on: PulsePalette.backgroundLightRGBA, minimum: 3),
        ContrastPair("run on background", PulsePalette.runLightRGBA, on: PulsePalette.backgroundLightRGBA, minimum: 3)
    ]
    for pair in pairs {
        #expect(pair.ratio >= pair.minimum, "\(pair.description)")
    }
}

/// La session en direct, le récap, la Live Activity et les widgets sont sombres : le texte y vaut 4,5:1 sur le noir de la
/// séance et sur les deux surfaces sombres.
@Test func darkPairsMeetWCAGAA() {
    let backgrounds: [(String, PulseRGBA)] = [
        ("liveBackground", PulsePalette.liveBackgroundRGBA), ("surface", PulsePalette.surfaceRGBA),
        ("surface2", PulsePalette.surface2RGBA)
    ]
    let texts: [(String, PulseRGBA)] = [
        ("text", PulsePalette.textRGBA), ("text2", PulsePalette.text2RGBA), ("muted", PulsePalette.mutedRGBA),
        ("warn", PulsePalette.warnRGBA), ("bad", PulsePalette.badRGBA), ("run", PulsePalette.runRGBA),
        ("gold", PulsePalette.goldRGBA)
    ]
    var pairs = texts.flatMap { text in backgrounds.map { ContrastPair("\(text.0) on \($0.0)", text.1, on: $0.1) } }
    for theme in [Theme.amber, .amethyst] {
        let palette = PulsePalette.accent(for: theme)
        pairs += [
            ContrastPair("\(theme) accentInk on accent", palette.accentInk.dark, on: palette.accent.dark),
            ContrastPair("\(theme) accentInk on accent2", palette.accentInk.dark, on: palette.accent2.dark)
        ]
    }
    for pair in pairs {
        #expect(pair.ratio >= pair.minimum, "\(pair.description)")
    }
}

/// Les teintes de l'audit A §3, au tirage près.
@Test func lightTokensCarryTheAuditedValues() {
    #expect(PulsePalette.mutedLightRGBA == PulseRGBA(hex: 0x68655F))
    #expect(PulsePalette.warnLightRGBA == PulseRGBA(hex: 0x6D6A64))
    #expect(PulsePalette.badLightRGBA == PulseRGBA(hex: 0xC02B08))
    #expect(PulsePalette.opalBadLightRGBA == PulseRGBA(hex: 0xC02B08))
    #expect(PulsePalette.goldLightRGBA == PulseRGBA(hex: 0x75623A))
}

private func hex(_ color: PulseRGBA) -> UInt32 {
    func byte(_ value: Double) -> UInt32 { UInt32((value * 255).rounded()) }
    return byte(color.red) << 16 | byte(color.green) << 8 | byte(color.blue)
}

/// Presque monochrome, dans les deux apparences : tout est gris neutre ou teinté, sauf le signal. La chroma (écart entre la
/// composante la plus forte et la plus faible) mesure la couleur sans s'affoler sur les quasi-noirs, contrairement à la
/// saturation.
@Test func onlyTheSignalCarriesColor() {
    func chroma(_ color: PulseRGBA) -> Double {
        max(color.red, color.green, color.blue) - min(color.red, color.green, color.blue)
    }
    let dark = [
        PulsePalette.surfaceRGBA, PulsePalette.surface2RGBA, PulsePalette.textRGBA, PulsePalette.text2RGBA,
        PulsePalette.mutedRGBA, PulsePalette.okRGBA, PulsePalette.warnRGBA, PulsePalette.runRGBA, PulsePalette.goldRGBA,
        PulsePalette.opalWarnRGBA, PulsePalette.accent(for: .amber).accent.dark, PulsePalette.accent(for: .amethyst).accent.dark
    ]
    let light = [
        PulsePalette.backgroundLightRGBA, PulsePalette.surfaceLightRGBA, PulsePalette.surface2LightRGBA,
        PulsePalette.textLightRGBA, PulsePalette.text2LightRGBA, PulsePalette.mutedLightRGBA, PulsePalette.okLightRGBA,
        PulsePalette.warnLightRGBA, PulsePalette.runLightRGBA, PulsePalette.opalWarnLightRGBA,
        PulsePalette.accent(for: .amber).accent.light, PulsePalette.accent(for: .amethyst).accent.light
    ]
    for color in dark + light {
        #expect(chroma(color) < 0.15)
    }
    #expect(chroma(PulsePalette.badRGBA) > 0.7)
    #expect(chroma(PulsePalette.badLightRGBA) > 0.7)
}

@Test func metricsGrowWithHierarchy() {
    #expect(PulseMetrics.radiusHero == 34 && PulseMetrics.radius == 26)
    #expect(PulseMetrics.radiusSmall == 16 && PulseMetrics.radiusTiny == 12)
    #expect(PulseMetrics.minButtonHeight == 56 && PulseMetrics.spacing == 16)
}

@Test func slabLightFollowsTheScore() {
    #expect(OpalCard<EmptyView>.temperature(for: 100) == 1)
    #expect(OpalCard<EmptyView>.temperature(for: 25) == 0.25)
    #expect(OpalCard<EmptyView>.temperature(for: -10) == 0)
    #expect(OpalCard<EmptyView>.temperature(for: nil) == 0.55)
    #expect(OpalCard<EmptyView>.temperature(for: .nan) == 0.55)
}

@Test func liveSessionBackgroundIsPureBlack() {
    #expect(PulsePalette.liveBackgroundRGBA == PulseRGBA(hex: 0x000000))
    #expect(PulsePalette.liveBackgroundRGBA.opacity == 1)
}
