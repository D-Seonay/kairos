import Foundation
import PulseDomain

/// Calcule le score de récupération d'un jour à partir de la nuit du jour et des nuits précédentes (spec §6.2, §6.3).
public struct RecoveryCalculator: Sendable {
    public static let hrvWindowDays = 14
    public static let restingHeartRateWindowDays = 7
    public static let restingHeartRateMinimumValues = 3
    /// Poids nominaux VFC 0,50 / FC repos 0,25 / sommeil 0,25 (spec §6.2).
    public static func nominalWeight(for factor: Factor) -> Double {
        switch factor {
        case .hrv: 0.50
        case .restingHeartRate: 0.25
        case .sleep: 0.25
        }
    }
    /// En dessous de ce nombre de facteurs présents, le score laisse place au check-in.
    public static let minimumFactors = 2

    private let calendar: Calendar

    public init(calendar: Calendar) {
        self.calendar = calendar
    }

    public func compute(day: Date, today: NightSample, history: [NightSample]) -> RecoveryOutcome {
        let hrv = hrvFactor(day: day, today: today, history: history)
        let present = [
            hrv.score,
            restingHeartRateFactor(day: day, today: today, history: history),
            sleepFactor(today: today)
        ].compactMap { $0 }

        let missing = Factor.allCases.filter { factor in !present.contains { $0.factor == factor } }
        guard present.count >= Self.minimumFactors else {
            return .needsCheckIn(missing: missing)
        }

        let totalWeight = present.reduce(0) { $0 + Self.nominalWeight(for: $1.factor) }
        let factors = present.map { partial in
            FactorScore(factor: partial.factor, score: partial.score,
                        weight: Self.nominalWeight(for: partial.factor) / totalWeight,
                        todayValue: partial.todayValue, baselineValue: partial.baselineValue)
        }
        let score = factors.reduce(0) { $0 + $1.score * $1.weight }
        return .measured(RecoveryResult(day: day, score: score, category: RecoveryCategory(score: score),
                                        factors: factors, missing: missing, calibration: hrv.calibration))
    }

    // MARK: - Facteurs

    private struct PartialFactor {
        let factor: Factor
        let score: Double
        let todayValue: Double
        let baselineValue: Double?
    }

    private func hrvFactor(day: Date, today: NightSample,
                           history: [NightSample]) -> (score: PartialFactor?, calibration: CalibrationState) {
        let values = history
            .filter { offset(from: $0, to: day).map { (1...Self.hrvWindowDays).contains($0) } ?? false }
            .compactMap(\.sdnnMs)
        let calibration: CalibrationState = values.count < Self.hrvWindowDays ? .calibrating(nights: values.count) : .ready

        guard let baseline = HRVBaseline(sdnnValuesMs: values),
              let sdnn = today.sdnnMs, HRVBaseline.isValid(sdnnMs: sdnn) else {
            return (nil, calibration)
        }
        let factor = PartialFactor(factor: .hrv, score: HRVScorer.score(zScore: baseline.zScore(sdnnMs: sdnn)),
                                   todayValue: sdnn, baselineValue: exp(baseline.mean))
        return (factor, calibration)
    }

    private func restingHeartRateFactor(day: Date, today: NightSample, history: [NightSample]) -> PartialFactor? {
        let values = history
            .filter { offset(from: $0, to: day).map { (1...Self.restingHeartRateWindowDays).contains($0) } ?? false }
            .compactMap(\.restingHeartRate)
        guard values.count >= Self.restingHeartRateMinimumValues, let bpm = today.restingHeartRate else { return nil }
        let mean = values.reduce(0, +) / Double(values.count)
        return PartialFactor(factor: .restingHeartRate, score: RHRScorer.score(todayBpm: bpm, baselineMeanBpm: mean),
                             todayValue: bpm, baselineValue: mean)
    }

    private func sleepFactor(today: NightSample) -> PartialFactor? {
        guard let sleep = today.sleep else { return nil }
        return PartialFactor(factor: .sleep, score: SleepScorer.score(asleepMinutes: sleep.asleepMinutes, deepMinutes: sleep.deepMinutes),
                             todayValue: Double(sleep.asleepMinutes), baselineValue: nil)
    }

    /// Nombre de jours calendaires entre la nuit et le jour calculé.
    private func offset(from night: NightSample, to day: Date) -> Int? {
        calendar.dateComponents([.day], from: night.day, to: day).day
    }
}
