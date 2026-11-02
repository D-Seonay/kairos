import PulseDomain

/// Ce que le jour permet pour les charges (spec M4 §8.1, tableau « Politique du jour »).
public struct ProgressionPolicy: Sendable, Equatable, Codable {
    public var allowsIncrease: Bool

    public init(allowsIncrease: Bool) {
        self.allowsIncrease = allowsIncrease
    }

    /// La hausse est permise sans adaptation, sans score, ou avec un score mesuré, calibré, optimal ou normal.
    /// Un facteur manquant ne la bloque pas ; un score estimé, une calibration en cours, la fatigue et le surmenage la bloquent
    /// (« Séance d'origine » après un surmenage comprise).
    public static func make(recovery: DailyRecovery?, adaptationEnabled: Bool, startsOriginalAfterOverreach: Bool) -> ProgressionPolicy {
        guard adaptationEnabled, let recovery else { return ProgressionPolicy(allowsIncrease: true) }
        guard !startsOriginalAfterOverreach, !recovery.isEstimated, recovery.calibration == .ready else {
            return ProgressionPolicy(allowsIncrease: false)
        }
        switch recovery.category {
        case .optimal, .normal: return ProgressionPolicy(allowsIncrease: true)
        case .moderateFatigue, .overreached: return ProgressionPolicy(allowsIncrease: false)
        }
    }
}
