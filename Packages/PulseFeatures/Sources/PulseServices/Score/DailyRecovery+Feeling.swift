import Foundation
import PulseDomain
import PulseRecoveryEngine

extension DailyRecovery {
    /// Le score mesuré avant le ressenti du matin : les sous-scores enregistrés, pondérés comme dans le calcul ; `nil` pour un
    /// score estimé.
    public var measuredScore: Double? {
        guard !isEstimated else { return nil }
        let present: [(factor: Factor, score: Double)] = Factor.allCases.compactMap { factor in
            guard !missingFactors.contains(factor) else { return nil }
            let score: Double? = switch factor {
            case .hrv: hrvScore
            case .restingHeartRate: restingHeartRateScore
            case .sleep: sleepScore
            }
            return score.map { (factor, $0) }
        }
        return present.isEmpty ? nil : RecoveryCalculator.weightedScore(present)
    }

    /// Ce que le ressenti `checkIn` change à ce score mesuré ; `nil` pour un score estimé ou sans check-in.
    public func feeling(_ checkIn: CheckIn?) -> FeelingAdjustment.Result? {
        guard let checkIn, let measuredScore else { return nil }
        return FeelingAdjustment.apply(measured: measuredScore, checkInScore: CheckInScorer.score(checkIn.answers))
    }
}
