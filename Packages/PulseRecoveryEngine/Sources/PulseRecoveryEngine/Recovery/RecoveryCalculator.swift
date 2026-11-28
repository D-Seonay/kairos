import Foundation
import PulseDomain

/// Calcule le score de récupération d'un jour à partir de la nuit du jour et des nuits précédentes (spec §6.2, §6.3).
public struct RecoveryCalculator: Sendable {
    /// La fenêtre de la ligne de base VFC (médiane et MAD), en jours avant le jour calculé.
    public static let hrvWindowDays = 14
    /// La fenêtre où se compte la calibration : plus large que la ligne de base, pour qu'une nuit sans montre dans la
    /// quinzaine ne fasse pas repartir la calibration.
    public static let calibrationWindowDays = 28
    /// Le nombre de nuits valides qu'il faut dans la fenêtre de calibration pour que la ligne de base soit dite prête.
    public static let calibrationNights = 14
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

    let calendar: Calendar

    public init(calendar: Calendar) {
        self.calendar = calendar
    }

    /// `sleepGoalMinutes` : l'objectif de sommeil du profil, contre lequel le facteur sommeil mesure la durée et la dette.
    /// `checkIn` : le ressenti du matin, qui ajoute au score mesuré un léger modificateur (`FeelingAdjustment`).
    public func compute(day: Date, today: NightSample, history: [NightSample],
                        sleepGoalMinutes: Int = SleepGoal.defaultMinutes, checkIn: CheckInAnswers? = nil) -> RecoveryOutcome {
        let hrv = hrvFactor(day: day, today: today, history: history)
        let restingHeartRate = restingHeartRateFactor(day: day, today: today, history: history)
        let sleep = sleepFactor(day: day, today: today, history: history, goalMinutes: sleepGoalMinutes)
        let present = [hrv.score, restingHeartRate, sleep.score].compactMap { $0 }

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
        let measured = Self.weightedScore(present.map { ($0.factor, $0.score) })
        let feeling = checkIn.map { FeelingAdjustment.apply(measured: measured, checkInScore: CheckInScorer.score($0)) }
        let score = feeling?.score ?? measured
        let insight = RecoveryInsight(hrvBaselineNights: hrv.nights.used, hrvSetAsideNights: hrv.nights.setAside,
                                      restingHeartRateSource: restingHeartRate == nil ? nil : today.restingHeartRateSource,
                                      sleepDebtMinutes: sleep.debtMinutes)
        return .measured(RecoveryResult(day: day, score: score, category: RecoveryCategory(score: score),
                                        factors: factors, missing: missing, calibration: hrv.calibration,
                                        insight: insight, feeling: feeling))
    }

    /// Ce que l'écran « Pourquoi » dit du calcul (nuits de la ligne de base, origine de la FC de repos, dette de sommeil), même
    /// quand le score lui-même est figé ou enregistré.
    public func insight(day: Date, today: NightSample, history: [NightSample],
                        sleepGoalMinutes: Int = SleepGoal.defaultMinutes) -> RecoveryInsight {
        let nights = hrvNights(day: day, history: history)
        let hasRestingHeartRate = restingHeartRateFactor(day: day, today: today, history: history) != nil
        return RecoveryInsight(hrvBaselineNights: nights.used, hrvSetAsideNights: nights.setAside,
                               restingHeartRateSource: hasRestingHeartRate ? today.restingHeartRateSource : nil,
                               sleepDebtMinutes: sleepFactor(day: day, today: today, history: history,
                                                             goalMinutes: sleepGoalMinutes).debtMinutes)
    }

    /// Le score pondéré des sous-scores présents : poids nominaux renormalisés sur eux. Le même calcul relit un score enregistré.
    public static func weightedScore(_ scores: [(factor: Factor, score: Double)]) -> Double {
        let total = scores.reduce(0) { $0 + nominalWeight(for: $1.factor) }
        guard total > 0 else { return 0 }
        return scores.reduce(0) { $0 + $1.score * nominalWeight(for: $1.factor) / total }
    }

    /// Nombre de jours calendaires entre la nuit et le jour calculé.
    func offset(from night: NightSample, to day: Date) -> Int? {
        calendar.dateComponents([.day], from: night.day, to: day).day
    }

    /// Les nuits des `days` jours calendaires d'avant `day`, le jour lui-même exclu.
    func nights(of history: [NightSample], before day: Date, days: Int) -> [NightSample] {
        history.filter { offset(from: $0, to: day).map { (1...days).contains($0) } ?? false }
    }
}

/// Ce que le calcul dit de lui-même, pour l'écran « Pourquoi ». Recalculé à la volée, jamais enregistré.
public struct RecoveryInsight: Sendable, Equatable {
    /// Les nuits sur lesquelles repose la ligne de base VFC (0 sans ligne de base).
    public var hrvBaselineNights: Int
    /// Les nuits de la fenêtre écartées faute d'assez de mesures SDNN (`HRVBaseline.minimumSamplesPerNight`).
    public var hrvSetAsideNights: Int
    /// D'où vient la FC de repos du jour ; `nil` quand elle ne compte pas, ou que sa source n'est pas connue.
    public var restingHeartRateSource: RestingHeartRateSource?
    /// La dette de sommeil des 7 nuits, en minutes ; `nil` sans sommeil la dernière nuit.
    public var sleepDebtMinutes: Int?

    public init(hrvBaselineNights: Int, hrvSetAsideNights: Int, restingHeartRateSource: RestingHeartRateSource?,
                sleepDebtMinutes: Int?) {
        self.hrvBaselineNights = hrvBaselineNights
        self.hrvSetAsideNights = hrvSetAsideNights
        self.restingHeartRateSource = restingHeartRateSource
        self.sleepDebtMinutes = sleepDebtMinutes
    }
}
