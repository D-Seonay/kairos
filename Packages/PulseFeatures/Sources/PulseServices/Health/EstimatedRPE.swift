import Foundation

/// Le RPE d'une course ou d'un vélo lu d'Apple Santé, estimé depuis la fréquence cardiaque moyenne (spec M6 §3).
public enum EstimatedRPE {
    /// La FC max retenue sans date de naissance.
    static let defaultMaxHeartRate = 190.0

    /// FC max de Tanaka : 208 − 0,7 × âge ; `defaultMaxHeartRate` sans date de naissance.
    public static func maxHeartRate(birthDate: Date?, at date: Date, calendar: Calendar) -> Double {
        guard let birthDate, let age = calendar.dateComponents([.year], from: birthDate, to: date).year, age > 0 else {
            return defaultMaxHeartRate
        }
        return 208 - 0.7 * Double(age)
    }

    /// 2 jusqu'à 50 % de la FC max, puis +1 par 10 points jusqu'à 60 %, +1 par 5 points jusqu'à 95 %, 10 au-delà ; arrondi au
    /// demi-point. `nil` sans fréquence cardiaque.
    public static func rpe(averageHeartRate: Double?, maxHeartRate: Double) -> Double? {
        guard let averageHeartRate, averageHeartRate > 0, maxHeartRate > 0 else { return nil }
        let share = averageHeartRate / maxHeartRate
        let raw = switch share {
        case ..<0.5: 2.0
        case ..<0.6: 2 + (share - 0.5) * 10
        case ..<0.95: 3 + (share - 0.6) * 20
        default: 10.0
        }
        return min(10, max(2, (raw * 2).rounded() / 2))
    }
}
