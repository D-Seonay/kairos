import PulseDomain
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
    let amber = PulsePalette.accent(for: .amber)
    #expect(amber.accent == PulseRGBA(hex: 0xF59E0B))
    #expect(amber.accent2 == PulseRGBA(hex: 0xEA580C))
    #expect(amber.accentInk == PulseRGBA(hex: 0x1A1206))
    #expect(amber.softOpacity == 0.16)

    let amethyst = PulsePalette.accent(for: .amethyst)
    #expect(amethyst.accent == PulseRGBA(hex: 0xA855F7))
    #expect(amethyst.accent2 == PulseRGBA(hex: 0x6366F1))
    #expect(amethyst.accentInk == PulseRGBA(hex: 0xFFFFFF))
    #expect(amethyst.softOpacity == 0.18)
}

@Test func baseTokensMatchTheMockup() {
    #expect(PulsePalette.backgroundRGBA == PulseRGBA(hex: 0x0B0C10))
    #expect(PulsePalette.surfaceRGBA == PulseRGBA(hex: 0x13151C))
    #expect(PulsePalette.opalInkRGBA == PulseRGBA(hex: 0x0A0B0F))
    #expect(PulsePalette.muscleBodyRGBA == PulseRGBA(hex: 0x262932))
    #expect(PulsePalette.muscleOffRGBA == PulseRGBA(hex: 0x3A3F4B))
    #expect(PulsePalette.lineRGBA.opacity == 0.08)
}

@Test func metricsMatchTheMockup() {
    #expect(PulseMetrics.radius == 22 && PulseMetrics.radiusSmall == 14 && PulseMetrics.radiusTiny == 10)
    #expect(PulseMetrics.minButtonHeight == 50 && PulseMetrics.spacing == 16)
}

@Test func liveSessionBackgroundIsPureBlack() {
    #expect(PulsePalette.liveBackgroundRGBA == PulseRGBA(hex: 0x000000))
    #expect(PulsePalette.liveBackgroundRGBA.opacity == 1)
}
