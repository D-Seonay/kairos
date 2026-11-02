/// Estimation du maximum sur une répétition par la formule de Brzycki (spec M4 §8.2).
public enum OneRepMax {
    public static let maxReps = 12

    /// `charge × 36 / (37 − répétitions)` pour 1 à 12 répétitions et une charge positive, sinon `nil`.
    public static func brzycki(weightKg: Double, reps: Int) -> Double? {
        guard weightKg > 0, (1...maxReps).contains(reps) else { return nil }
        return weightKg * 36 / Double(37 - reps)
    }
}
