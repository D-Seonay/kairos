import Foundation
import PulseDesignSystem
@testable import StatsFeature
import Testing

/// WCAG 1.4.11 : une série, une barre ou un niveau d'assiduité qui porte une information atteint 3:1 contre le papier et contre
/// la carte. Le papier est le thème clair, forcé dans l'app. Les helpers de contraste sont ceux du design system, refaits ici
/// parce que ceux du design system sont internes à ses tests.
private enum Contrast {
    private static func channel(_ value: Double) -> Double {
        value <= 0.03928 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
    }

    private static func luminance(_ red: Double, _ green: Double, _ blue: Double) -> Double {
        0.2126 * channel(red) + 0.7152 * channel(green) + 0.0722 * channel(blue)
    }

    /// L'encre à l'opacité donnée, posée sur `background`, contre `background`.
    static func ink(opacity: Double, on background: PulseRGBA) -> Double {
        let ink = PulsePalette.inkLightRGBA
        let mixed = luminance(ink.red * opacity + background.red * (1 - opacity),
                              ink.green * opacity + background.green * (1 - opacity),
                              ink.blue * opacity + background.blue * (1 - opacity))
        let paper = luminance(background.red, background.green, background.blue)
        return (max(mixed, paper) + 0.05) / (min(mixed, paper) + 0.05)
    }
}

struct StatsInkContrastTests {
    private let papers: [(name: String, color: PulseRGBA)] = [
        ("background", PulsePalette.backgroundLightRGBA), ("surface", PulsePalette.surfaceLightRGBA)
    ]

    @Test func informativeInksReachThreeToOne() {
        let inks: [(String, Double)] = [("full", StatsInk.fullOpacity), ("medium", StatsInk.mediumOpacity),
                                        ("light", StatsInk.lightOpacity)]
        for paper in papers {
            for (name, opacity) in inks {
                let ratio = Contrast.ink(opacity: opacity, on: paper.color)
                #expect(ratio >= 3, "\(name) on \(paper.name): \(ratio)")
            }
        }
    }

    @Test func attendanceLevelsThatCarryInformationReachThreeToOne() {
        #expect(StatsInk.attendanceOpacities.count == 5)
        for paper in papers {
            // Le niveau 0 est le fond de la grille, pas une information : le jour sans séance se lit par son absence d'encre.
            for (level, opacity) in StatsInk.attendanceOpacities.enumerated().dropFirst() {
                let ratio = Contrast.ink(opacity: opacity, on: paper.color)
                #expect(ratio >= 3, "level \(level) on \(paper.name): \(ratio)")
            }
        }
    }

    @Test func attendanceLevelsGetDarkerWithTheLoad() {
        let opacities = StatsInk.attendanceOpacities
        #expect(opacities == opacities.sorted() && Set(opacities).count == opacities.count)
        #expect(opacities.last == 1)
    }

    @Test func seriesInksAreDistinct() {
        #expect(StatsInk.fullOpacity > StatsInk.mediumOpacity && StatsInk.mediumOpacity > StatsInk.lightOpacity)
        #expect(StatsInk.fullOpacity - StatsInk.mediumOpacity >= 0.2 && StatsInk.mediumOpacity - StatsInk.lightOpacity >= 0.2)
    }

    /// La bande optimale du ratio est un fond : la zone est dite par le texte (« zone optimale de 0,8 à 1,3 ») et par les
    /// repères de l'axe, elle ne porte rien seule.
    @Test func zoneBandStaysDecorative() {
        #expect(StatsInk.zoneOpacity < StatsInk.lightOpacity)
    }
}
