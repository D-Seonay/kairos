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

/// Le texte reste lisible sur le papier : au moins 4,5:1 pour le texte secondaire (WCAG AA).
@Test func lightTextContrastsWithThePaper() {
    func luminance(_ color: PulseRGBA) -> Double {
        func channel(_ value: Double) -> Double {
            value <= 0.03928 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(color.red) + 0.7152 * channel(color.green) + 0.0722 * channel(color.blue)
    }
    func contrast(_ first: PulseRGBA, _ second: PulseRGBA) -> Double {
        let (high, low) = (max(luminance(first), luminance(second)), min(luminance(first), luminance(second)))
        return (high + 0.05) / (low + 0.05)
    }
    #expect(contrast(PulsePalette.textLightRGBA, PulsePalette.backgroundLightRGBA) > 15)
    #expect(contrast(PulsePalette.text2LightRGBA, PulsePalette.backgroundLightRGBA) > 4.5)
    #expect(contrast(PulsePalette.text2LightRGBA, PulsePalette.surfaceLightRGBA) > 4.5)
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
