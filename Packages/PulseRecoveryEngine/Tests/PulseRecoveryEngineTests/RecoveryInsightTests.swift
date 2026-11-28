import Foundation
import PulseDomain
@testable import PulseRecoveryEngine
import Testing

/// Ligne de base VFC robuste (#115), dette de sommeil (#117), FC de repos nocturne (#118) et ressenti du matin (#119).
@Suite struct RecoveryInsightTests {
    let calculator = RecoveryCalculator(calendar: TestCalendar.paris)
    let day = TestCalendar.day(2026, 11, 20)

    /// 14 nuits à 8 h de sommeil (pas de dette), SDNN 48 à 52 ms mesurée 4 fois, FC repos 50 la plus basse de la nuit.
    func history(sdnn: (Int) -> Double = { 48 + Double($0 % 5) }, samples: (Int) -> Int? = { _ in 4 },
                 source: RestingHeartRateSource? = .overnightLowest, rhr: Double = 50, apple: Double? = nil) -> [NightSample] {
        (1...14).map { age in
            NightSample(day: TestCalendar.shift(day, by: -age), sdnnMs: sdnn(age), sdnnSampleCount: samples(age),
                        restingHeartRate: rhr, restingHeartRateSource: source, appleRestingHeartRate: apple,
                        sleep: .init(asleepMinutes: 480, deepMinutes: 96))
        }
    }

    func today(sdnn: Double? = 50, rhr: Double? = 50, source: RestingHeartRateSource? = .overnightLowest,
               apple: Double? = nil, asleep: Int = 480) -> NightSample {
        NightSample(day: day, sdnnMs: sdnn, sdnnSampleCount: 4, restingHeartRate: rhr, restingHeartRateSource: source,
                    appleRestingHeartRate: apple, sleep: .init(asleepMinutes: asleep, deepMinutes: asleep / 5))
    }

    func restingHeartRate(_ result: RecoveryResult) -> FactorScore? {
        result.factors.first { $0.factor == .restingHeartRate }
    }

    func measured(_ outcome: RecoveryOutcome) throws -> RecoveryResult {
        guard case .measured(let result) = outcome else { throw Unexpected() }
        return result
    }

    struct Unexpected: Error {}

    // MARK: - #115

    /// Une nuit aberrante (SDNN 15 ms, alcool ou maladie) dans la quinzaine : le score du lendemain ne bouge presque pas.
    @Test func oneOutlierNightBarelyMovesTomorrowsScore() throws {
        let clean = try measured(calculator.compute(day: day, today: today(sdnn: 46), history: history()))
        let noisy = try measured(calculator.compute(day: day, today: today(sdnn: 46),
                                                    history: history(sdnn: { $0 == 2 ? 15 : 48 + Double($0 % 5) })))
        #expect(abs(noisy.score - clean.score) < 2)
    }

    @Test func nightsWithASingleSDNNSampleAreSetAside() throws {
        let sparse = history(samples: { [1, 3, 5].contains($0) ? 1 : 4 })
        let result = try measured(calculator.compute(day: day, today: today(), history: sparse))
        #expect(result.insight?.hrvBaselineNights == 11)
        #expect(result.insight?.hrvSetAsideNights == 3)
        #expect(result.calibration == .ready, "La calibration compte toujours les 14 nuits valides")
    }

    /// Une montre qui ne mesure qu'une fois par nuit garde sa VFC : faute de 5 nuits bien mesurées, toutes servent.
    @Test func sparseWatchesKeepTheirBaseline() throws {
        let result = try measured(calculator.compute(day: day, today: today(), history: history(samples: { _ in 1 })))
        #expect(result.missing.isEmpty)
        #expect(result.insight?.hrvBaselineNights == 14)
        #expect(result.insight?.hrvSetAsideNights == 0)
    }

    @Test func withoutABaselineNoNightIsCounted() throws {
        let short = Array(history().prefix(3))
        let result = try measured(calculator.compute(day: day, today: today(), history: short))
        #expect(result.insight?.hrvBaselineNights == 0)
    }

    // MARK: - #117

    /// Trois nuits de 5 h 30 puis une nuit de 8 h : le facteur sommeil n'est plus parfait.
    @Test func threeShortNightsThenAGoodOneLeaveADebt() throws {
        var nights = history()
        for age in 1...3 { nights[age - 1].sleep = .init(asleepMinutes: 330, deepMinutes: 66) }
        let result = try measured(calculator.compute(day: day, today: today(), history: nights))
        #expect(result.factors.first { $0.factor == .sleep }?.score == 79.9375) // 70 % × 100 + 30 % × 33,125
        #expect(result.insight?.sleepDebtMinutes == 321) // 150 × (6 + 5 + 4) / 7
    }

    @Test func noDebtWithoutSleepLastNight() {
        var night = today()
        night.sleep = nil
        #expect(calculator.insight(day: day, today: night, history: history()).sleepDebtMinutes == nil)
    }

    // MARK: - #118

    @Test func theRestingHeartRateSourceIsReported() throws {
        let result = try measured(calculator.compute(day: day, today: today(), history: history()))
        #expect(result.insight?.restingHeartRateSource == .overnightLowest)
        let fallback = try measured(calculator.compute(day: day, today: today(source: .appleNearWake),
                                                       history: history(source: .appleNearWake)))
        #expect(fallback.insight?.restingHeartRateSource == .appleNearWake)
    }

    /// La référence compare ce qui est comparable : une nuit « FC la plus basse » face aux nuits de même source.
    @Test func theReferenceUsesNightsOfTheSameSource() throws {
        var nights = history()
        for age in 1...3 {
            nights[age - 1].restingHeartRate = 58
            nights[age - 1].restingHeartRateSource = .appleNearWake
        }
        let result = try measured(calculator.compute(day: day, today: today(rhr: 50), history: nights))
        #expect(result.factors.first { $0.factor == .restingHeartRate }?.baselineValue == 50)
    }

    /// Une semaine de nuits « FC la plus basse » (50, Apple à 56), puis une nuit trop peu mesurée lue chez Apple (56) : elle se
    /// compare aux valeurs Apple des mêmes nuits, pas aux minima nocturnes, et ne perd pas 13 points sans que rien n'ait changé.
    @Test func anAppleNightIsComparedWithTheAppleValuesOfOvernightNights() throws {
        let nights = history(apple: 56)
        let result = try measured(calculator.compute(day: day, today: today(rhr: 56, source: .appleNearWake, apple: 56),
                                                     history: nights))
        #expect(restingHeartRate(result)?.baselineValue == 56)
        #expect(restingHeartRate(result)?.score == 100)
        #expect(result.insight?.restingHeartRateSource == .appleNearWake)
    }

    @Test func anAppleNightWithoutAppleReferenceHasNoRestingHeartRate() throws {
        let result = try measured(calculator.compute(day: day, today: today(rhr: 56, source: .appleNearWake, apple: 56),
                                                     history: history()))
        #expect(result.missing.contains(.restingHeartRate))
        #expect(result.insight?.restingHeartRateSource == nil)
    }

    /// Le sens inverse : une nuit « FC la plus basse » (50) après une semaine Apple (56) ne gagne pas 100 d'office ; elle compare
    /// son propre échantillon Apple (57) aux nuits Apple.
    @Test func anOvernightNightAfterAppleNightsComparesItsAppleValue() throws {
        let nights = history(source: .appleNearWake, rhr: 56, apple: 56)
        let result = try measured(calculator.compute(day: day, today: today(rhr: 50, apple: 57), history: nights))
        #expect(restingHeartRate(result)?.baselineValue == 56)
        #expect(restingHeartRate(result)?.todayValue == 57)
        #expect(result.insight?.restingHeartRateSource == .appleNearWake)
    }

    @Test func anOvernightNightWithoutComparableNightsHasNoRestingHeartRate() throws {
        let nights = history(source: .appleNearWake, rhr: 56, apple: 56)
        let result = try measured(calculator.compute(day: day, today: today(rhr: 50), history: nights))
        #expect(result.missing.contains(.restingHeartRate))
        #expect(calculator.insight(day: day, today: today(rhr: 50), history: nights).restingHeartRateSource == nil)
    }

    // MARK: - #119

    @Test func aCheckInAddsACappedModifierToAMeasuredScore() throws {
        let without = try measured(calculator.compute(day: day, today: today(sdnn: 44, rhr: 54), history: history()))
        let feelingBad = CheckInAnswers(sleep: 0, pain: 0, motivation: 0)
        let with = try measured(calculator.compute(day: day, today: today(sdnn: 44, rhr: 54), history: history(),
                                                   checkIn: feelingBad))
        #expect(with.feeling?.measured == without.score)
        #expect(with.feeling?.points == -5)
        #expect(abs(with.score - (without.score - 5)) < 1e-9)
        #expect(with.category == RecoveryCategory(score: with.score))
        #expect(with.factors == without.factors, "Les sous-scores restent ceux de la mesure")
    }

    @Test func aGoodFeelingNeverLiftsTheCategory() throws {
        let tired = today(sdnn: 30, rhr: 60, asleep: 300)
        let without = try measured(calculator.compute(day: day, today: tired, history: history()))
        let great = CheckInAnswers(sleep: 4, pain: 4, motivation: 4)
        let with = try measured(calculator.compute(day: day, today: tired, history: history(), checkIn: great))
        #expect(with.category == without.category)
        #expect(with.score >= without.score)
    }

    @Test func theWeightedScoreMatchesTheCalculator() throws {
        let result = try measured(calculator.compute(day: day, today: today(sdnn: 44, rhr: 54), history: history()))
        let rebuilt = RecoveryCalculator.weightedScore(result.factors.map { ($0.factor, $0.score) })
        #expect(abs(rebuilt - result.score) < 1e-9)
    }
}
