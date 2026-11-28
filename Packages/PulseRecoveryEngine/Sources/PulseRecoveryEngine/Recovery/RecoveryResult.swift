import Foundation
import PulseDomain

/// Contribution d'un facteur au score du jour. `weight` est le poids après renormalisation sur les facteurs présents.
public struct FactorScore: Sendable, Equatable {
    public let factor: Factor
    public let score: Double
    public let weight: Double
    public let todayValue: Double
    public let baselineValue: Double?

    public init(factor: Factor, score: Double, weight: Double, todayValue: Double, baselineValue: Double?) {
        self.factor = factor
        self.score = score
        self.weight = weight
        self.todayValue = todayValue
        self.baselineValue = baselineValue
    }
}

/// Score de récupération d'un jour, avec son détail par facteur.
public struct RecoveryResult: Sendable, Equatable {
    public let day: Date
    public let score: Double
    public let category: RecoveryCategory
    /// Facteurs présents, toujours dans l'ordre `hrv`, `restingHeartRate`, `sleep`.
    public let factors: [FactorScore]
    /// Facteurs absents, dans le même ordre.
    public let missing: [Factor]
    public let calibration: CalibrationState
    /// Ce que le calcul dit de lui-même pour l'écran « Pourquoi ».
    public let insight: RecoveryInsight?
    /// Le ressenti du matin et ce qu'il change au score mesuré ; `nil` sans check-in. `score` est alors `feeling.score`.
    public let feeling: FeelingAdjustment.Result?

    public init(day: Date, score: Double, category: RecoveryCategory, factors: [FactorScore], missing: [Factor],
                calibration: CalibrationState, insight: RecoveryInsight? = nil, feeling: FeelingAdjustment.Result? = nil) {
        self.day = day
        self.score = score
        self.category = category
        self.factors = factors
        self.missing = missing
        self.calibration = calibration
        self.insight = insight
        self.feeling = feeling
    }

    /// La surcharge progressive n'est proposée qu'avec une ligne de base complète et tous les facteurs présents (spec §6.3).
    public var allowsProgressiveOverload: Bool {
        calibration == .ready && missing.isEmpty
    }
}

/// Résultat du calcul : un score mesuré, ou un check-in à demander quand trop de facteurs manquent.
public enum RecoveryOutcome: Sendable, Equatable {
    case measured(RecoveryResult)
    case needsCheckIn(missing: [Factor])
}
