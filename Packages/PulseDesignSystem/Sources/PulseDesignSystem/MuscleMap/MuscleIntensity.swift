import PulseDomain
import SwiftUI

/// Passe des poids par muscle aux niveaux 1 à 4 de la carte, et des niveaux aux couleurs. Chaque cas est un niveau :
/// `light` (1) à `maximum` (4).
public enum MuscleIntensity: Int, Sendable, CaseIterable, Comparable {
    case light = 1
    case moderate
    case strong
    case maximum

    /// Part d'accent dans le mélange avec `muscleOff` pour les niveaux 1 à 4. Le niveau 1 ressort à 3:1 contre le gris
    /// éteint (élément graphique porteur d'information, WCAG 1.4.11) ; la maquette partait de 0,32 / 0,56 / 0,80.
    static let accentShares = [0.5, 0.7, 0.85, 1]

    public static func < (lhs: MuscleIntensity, rhs: MuscleIntensity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Niveau = `max(1, ceil(poids / poidsMax × 4))` ; `nil` pour un poids nul ou sans poids maximal.
    private static func level(weight: Double, heaviest: Double) -> Int? {
        guard heaviest > 0, weight > 0 else { return nil }
        return max(1, Int((weight * 4 / heaviest).rounded(.up)))
    }

    /// Une région prend le niveau le plus haut des muscles qui la couvrent.
    public static func levels(weights: [Muscle: Double]) -> [MuscleMapRegion: Int] {
        let heaviest = weights.values.max() ?? 0
        var levels: [MuscleMapRegion: Int] = [:]
        for (muscle, weight) in weights {
            guard let level = level(weight: weight, heaviest: heaviest) else { continue }
            for region in muscle.mapRegions {
                levels[region] = max(levels[region] ?? 0, level)
            }
        }
        return levels
    }

    /// Le niveau de chaque muscle travaillé, par la même règle ; sert au résumé lu par VoiceOver.
    public static func byMuscle(weights: [Muscle: Double]) -> [Muscle: MuscleIntensity] {
        let heaviest = weights.values.max() ?? 0
        return weights.reduce(into: [:]) { result, entry in
            if let level = level(weight: entry.value, heaviest: heaviest), let intensity = MuscleIntensity(rawValue: min(level, 4)) {
                result[entry.key] = intensity
            }
        }
    }

    /// Le mélange sRGB de l'accent et de `muscleOff` pour ce niveau (`color-mix(in srgb, accent n%, off)`).
    public static func color(level: Int, accent: PulseRGBA, off: PulseRGBA = PulsePalette.muscleOffRGBA) -> PulseRGBA {
        let share = accentShares[min(max(level, 1), accentShares.count) - 1]
        func mix(_ lit: Double, _ unlit: Double) -> Double { lit * share + unlit * (1 - share) }
        return PulseRGBA(
            red: mix(accent.red, off.red), green: mix(accent.green, off.green), blue: mix(accent.blue, off.blue)
        )
    }
}

public extension MuscleIntensity {
    /// La couleur de ce niveau dans les deux apparences : l'accent du thème mêlé au `muscleOff` clair ou sombre.
    static func color(level: Int, accent: PulseTone) -> Color {
        Color(light: color(level: level, accent: accent.light, off: PulsePalette.muscleOffLightRGBA),
              dark: color(level: level, accent: accent.dark))
    }
}

private extension PulseRGBA {
    init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
        opacity = 1
    }
}
