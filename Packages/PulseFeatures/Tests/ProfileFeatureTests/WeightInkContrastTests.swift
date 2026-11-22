import Foundation
@testable import ProfileFeature
import PulseDesignSystem
import Testing

/// WCAG 1.4.11 : un point de pesée porte une information, il atteint 3:1 contre le papier et contre la carte. Les helpers de
/// contraste du design system sont internes à ses tests : ils sont refaits ici, comme pour les encres de Stats.
private enum Contrast {
    private static func channel(_ value: Double) -> Double {
        value <= 0.03928 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
    }

    private static func luminance(_ red: Double, _ green: Double, _ blue: Double) -> Double {
        0.2126 * channel(red) + 0.7152 * channel(green) + 0.0722 * channel(blue)
    }

    static func ink(opacity: Double, on background: PulseRGBA) -> Double {
        let ink = PulsePalette.inkLightRGBA
        let mixed = luminance(ink.red * opacity + background.red * (1 - opacity),
                              ink.green * opacity + background.green * (1 - opacity),
                              ink.blue * opacity + background.blue * (1 - opacity))
        let paper = luminance(background.red, background.green, background.blue)
        return (max(mixed, paper) + 0.05) / (min(mixed, paper) + 0.05)
    }
}

struct WeightInkContrastTests {
    private let papers: [(name: String, color: PulseRGBA)] = [
        ("background", PulsePalette.backgroundLightRGBA), ("surface", PulsePalette.surfaceLightRGBA)
    ]

    @Test func weighInAndTrendReachThreeToOne() {
        for paper in papers {
            for (name, opacity) in [("weigh-in", WeightInk.weighInOpacity), ("trend", WeightInk.trendOpacity)] {
                let ratio = Contrast.ink(opacity: opacity, on: paper.color)
                #expect(ratio >= 3, "\(name) on \(paper.name): \(ratio)")
            }
        }
    }

    @Test func weighInsStayLighterThanTheTrend() {
        #expect(WeightInk.weighInOpacity < WeightInk.trendOpacity)
    }
}
