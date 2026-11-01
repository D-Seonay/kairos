import Foundation
import PulseDomain

/// Passe des poids par muscle aux niveaux 1 à 4 de la carte, et des niveaux aux couleurs.
public enum MuscleIntensity {
    /// Part d'accent dans le mélange avec `muscleOff` pour les niveaux 1 à 4 (`--h1` à `--h4` de la maquette).
    private static let accentShares = [0.32, 0.56, 0.80, 1]

    /// Niveau = `max(1, ceil(poids / poidsMax × 4))` ; une région prend le niveau le plus haut des muscles qui la couvrent.
    public static func levels(weights: [Muscle: Double]) -> [MuscleMapRegion: Int] {
        guard let heaviest = weights.values.max(), heaviest > 0 else { return [:] }
        var levels: [MuscleMapRegion: Int] = [:]
        for (muscle, weight) in weights where weight > 0 {
            let level = max(1, Int((weight * 4 / heaviest).rounded(.up)))
            for region in muscle.mapRegions {
                levels[region] = max(levels[region] ?? 0, level)
            }
        }
        return levels
    }

    /// Le mélange sRGB de l'accent et de `muscleOff` pour ce niveau (`color-mix(in srgb, accent n%, off)`).
    public static func color(level: Int, accent: PulseRGBA) -> PulseRGBA {
        let share = accentShares[min(max(level, 1), accentShares.count) - 1]
        let off = PulsePalette.muscleOffRGBA
        func mix(_ lit: Double, _ unlit: Double) -> Double { lit * share + unlit * (1 - share) }
        return PulseRGBA(
            red: mix(accent.red, off.red), green: mix(accent.green, off.green), blue: mix(accent.blue, off.blue)
        )
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
