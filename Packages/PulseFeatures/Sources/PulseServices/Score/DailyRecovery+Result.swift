import Foundation
import PulseDomain
import PulseRecoveryEngine

extension DailyRecovery {
    /// Un score mesuré : sous-scores, valeurs du jour et lignes de base viennent des facteurs du calcul, la durée de sommeil de la nuit.
    init(result: RecoveryResult, night: NightSample, now: Date) {
        func factor(_ factor: Factor) -> FactorScore? {
            result.factors.first { $0.factor == factor }
        }
        let hrv = factor(.hrv)
        let restingHeartRate = factor(.restingHeartRate)
        self.init(day: result.day, score: result.score, category: result.category, isEstimated: false,
                  hrvScore: hrv?.score, restingHeartRateScore: restingHeartRate?.score, sleepScore: factor(.sleep)?.score,
                  sdnnMs: hrv?.todayValue, sdnnBaselineMs: hrv?.baselineValue,
                  restingHeartRate: restingHeartRate?.todayValue, restingHeartRateBaseline: restingHeartRate?.baselineValue,
                  asleepMinutes: night.sleep?.asleepMinutes, deepMinutes: night.sleep?.deepMinutes,
                  coreMinutes: night.sleep?.coreMinutes, remMinutes: night.sleep?.remMinutes,
                  unspecifiedMinutes: night.sleep?.unspecifiedMinutes, awakeMinutes: night.sleep?.awakeMinutes,
                  missingFactors: result.missing, calibration: result.calibration, adjustments: [],
                  createdAt: now, updatedAt: now)
    }
}
