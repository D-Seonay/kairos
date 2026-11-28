import Foundation
import PulseDomain
@testable import PulseRecoveryEngine
import Testing

@Suite struct RecoveryCalculatorTests {
    let calculator = RecoveryCalculator(calendar: TestCalendar.paris)
    let day = TestCalendar.day(2026, 11, 20)

    /// 14 nuits, sdnn alternant 49 / 51, FC repos 50, 450 min dont 90 profond.
    var fourteenNights: [NightSample] {
        (1...14).map { i in
            NightSample(day: TestCalendar.shift(day, by: -i),
                        sdnnMs: i.isMultiple(of: 2) ? 49 : 51, restingHeartRate: 50,
                        sleep: .init(asleepMinutes: 450, deepMinutes: 90))
        }
    }

    func measured(_ outcome: RecoveryOutcome) throws -> RecoveryResult {
        guard case .measured(let result) = outcome else {
            Issue.record("expected measured, got \(outcome)")
            throw TestFailure()
        }
        return result
    }

    struct TestFailure: Error {}

    @Test func fourteenNightsReady() throws {
        let today = NightSample(day: day, sdnnMs: 60, restingHeartRate: 49, sleep: .init(asleepMinutes: 480, deepMinutes: 100))
        let r = try measured(calculator.compute(day: day, today: today, history: fourteenNights))
        // Sommeil : 100 la nuit dernière, mais 30 min de moins chacune des 6 nuits d'avant → 1 h 30 de dette (score 81,25).
        #expect(abs(r.score - 98.59375) < 1e-6)
        #expect(r.category == .optimal)
        #expect(r.calibration == .ready)
        #expect(r.missing.isEmpty)
        #expect(r.allowsProgressiveOverload)
        #expect(r.factors.map(\.weight) == [0.5, 0.25, 0.25])
        #expect(r.factors.map(\.factor) == [.hrv, .restingHeartRate, .sleep])
    }

    @Test func missingHRVRenormalizesWeights() throws {
        let today = NightSample(day: day, sdnnMs: nil, restingHeartRate: 52, sleep: .init(asleepMinutes: 420, deepMinutes: 84))
        let r = try measured(calculator.compute(day: day, today: today, history: fourteenNights))
        #expect(abs(r.score - 83.75) < 1e-6) // sommeil 91,25 la nuit dernière, 2 h 30 de dette
        #expect(r.category == .normal)
        #expect(r.missing == [.hrv])
        #expect(r.calibration == .ready)
        #expect(r.factors.map(\.weight) == [0.5, 0.5])
        #expect(r.factors.map(\.factor) == [.restingHeartRate, .sleep])
        #expect(r.allowsProgressiveOverload == false)
    }

    /// 14 nuits dont 3 avec une SDNN aberrante (0, 400, -5) : seules 11 comptent dans la calibration.
    @Test func calibrationCountsOnlyValidSDNNNights() throws {
        var history = fourteenNights
        history[0].sdnnMs = 0
        history[5].sdnnMs = 400
        history[9].sdnnMs = -5
        let today = NightSample(day: day, sdnnMs: 50, restingHeartRate: 50, sleep: .init(asleepMinutes: 480, deepMinutes: 96))
        let r = try measured(calculator.compute(day: day, today: today, history: history))
        #expect(r.calibration == .calibrating(nights: 11))
        #expect(r.missing.isEmpty)
    }

    @Test func eightNightsIsCalibrating() throws {
        let history = (1...8).map {
            NightSample(day: TestCalendar.shift(day, by: -$0), sdnnMs: 50, restingHeartRate: 50,
                        sleep: .init(asleepMinutes: 480, deepMinutes: 96))
        }
        let today = NightSample(day: day, sdnnMs: 50, restingHeartRate: 50, sleep: .init(asleepMinutes: 480, deepMinutes: 96))
        let r = try measured(calculator.compute(day: day, today: today, history: history))
        #expect(abs(r.score - 95) < 1e-6)
        #expect(r.calibration == .calibrating(nights: 8))
        #expect(r.missing.isEmpty)
        #expect(r.allowsProgressiveOverload == false)
    }

    @Test func threeNightsDropsHRVButKeepsOthers() throws {
        let history = (1...3).map {
            NightSample(day: TestCalendar.shift(day, by: -$0), sdnnMs: 50, restingHeartRate: 50,
                        sleep: .init(asleepMinutes: 450, deepMinutes: 90))
        }
        let today = NightSample(day: day, sdnnMs: 50, restingHeartRate: 50, sleep: .init(asleepMinutes: 450, deepMinutes: 90))
        let r = try measured(calculator.compute(day: day, today: today, history: history))
        #expect(r.missing == [.hrv])
        #expect(r.calibration == .calibrating(nights: 3))
        #expect(abs(r.score - 95.53125) < 1e-6) // 1 h 34 de dette sur les 4 nuits connues
    }

    @Test func twoMissingFactorsNeedsCheckIn() {
        let today = NightSample(day: day, sdnnMs: nil, restingHeartRate: nil, sleep: nil)
        let outcome = calculator.compute(day: day, today: today, history: [])
        #expect(outcome == .needsCheckIn(missing: [.hrv, .restingHeartRate, .sleep]))
    }

    /// 42 nuits dont une sur `stride` a une SDNN. La calibration compte les nuits valides des 28 jours d'avant (14 puis 9),
    /// la ligne de base celles des 14 jours d'avant (7, puis 4 : pas de ligne de base).
    @Test(arguments: [(2, CalibrationState.ready, [Factor]()), (3, CalibrationState.calibrating(nights: 9), [Factor.hrv])])
    func gapsInHistoryUseCalendarWindow(stride: Int, expected: CalibrationState, expectedMissing: [Factor]) throws {
        let history = (1...42).map { offset in
            NightSample(day: TestCalendar.shift(day, by: -offset),
                        sdnnMs: offset.isMultiple(of: stride) ? 50 : nil, restingHeartRate: 50, sleep: nil)
        }
        let today = NightSample(day: day, sdnnMs: 50, restingHeartRate: 50, sleep: .init(asleepMinutes: 480, deepMinutes: 96))
        let r = try measured(calculator.compute(day: day, today: today, history: history))
        #expect(r.calibration == expected)
        #expect(r.missing == expectedMissing)
    }

    /// 28 nuits, sdnn alternant 49 / 51, dont celles de `missing` (en jours avant le jour) n'ont pas de SDNN.
    func twentyEightNights(without missing: Set<Int> = []) -> [NightSample] {
        (1...28).map { i in
            NightSample(day: TestCalendar.shift(day, by: -i),
                        sdnnMs: missing.contains(i) ? nil : (i.isMultiple(of: 2) ? 49 : 51), restingHeartRate: 50,
                        sleep: .init(asleepMinutes: 450, deepMinutes: 90))
        }
    }

    /// La montre en charge une nuit dans la quinzaine : la calibration, comptée sur 28 jours, ne repart pas de 13 nuits.
    @Test func oneNightWithoutHRVKeepsTheCalibration() throws {
        let today = NightSample(day: day, sdnnMs: 60, restingHeartRate: 49, sleep: .init(asleepMinutes: 480, deepMinutes: 100))
        let r = try measured(calculator.compute(day: day, today: today, history: twentyEightNights(without: [4])))
        #expect(r.calibration == .ready)
        #expect(r.missing.isEmpty)
        #expect(r.allowsProgressiveOverload)
    }

    /// Un nouvel utilisateur a toujours besoin de 14 nuits : 13 nuits valides sur les 28 jours, c'est encore la calibration.
    @Test func thirteenValidNightsInTwentyEightDaysIsCalibrating() throws {
        let today = NightSample(day: day, sdnnMs: 50, restingHeartRate: 50, sleep: .init(asleepMinutes: 480, deepMinutes: 96))
        let thirteen = try measured(calculator.compute(day: day, today: today, history: twentyEightNights(without: Set(14...28))))
        #expect(thirteen.calibration == .calibrating(nights: 13))
        let spread = try measured(calculator.compute(day: day, today: today,
                                                     history: twentyEightNights(without: Set(stride(from: 1, through: 27, by: 2)))))
        #expect(spread.calibration == .ready, "14 nuits valides, une sur deux")
        let older = (29...60).map {
            NightSample(day: TestCalendar.shift(day, by: -$0), sdnnMs: 50, restingHeartRate: 50, sleep: nil)
        }
        let beyond = try measured(calculator.compute(day: day, today: today,
                                                     history: twentyEightNights(without: Set(14...28)) + older))
        #expect(beyond.calibration == .calibrating(nights: 13), "Les nuits d'avant les 28 jours ne comptent pas")
    }

    /// Seule la calibration regarde 28 jours : la moyenne et l'écart-type restent ceux des 14 nuits d'avant.
    @Test func theBaselineKeepsItsFourteenDayWindow() throws {
        let today = NightSample(day: day, sdnnMs: 50, restingHeartRate: 50, sleep: .init(asleepMinutes: 480, deepMinutes: 96))
        let older = (15...28).map {
            NightSample(day: TestCalendar.shift(day, by: -$0), sdnnMs: 120, restingHeartRate: 50, sleep: nil)
        }
        let short = try measured(calculator.compute(day: day, today: today, history: fourteenNights))
        let long = try measured(calculator.compute(day: day, today: today, history: fourteenNights + older))
        #expect(long.factors == short.factors)
        #expect(long.score == short.score)
    }

    @Test func todaySDNNOutOfRangeIsMissing() throws {
        let today = NightSample(day: day, sdnnMs: 0, restingHeartRate: 49, sleep: .init(asleepMinutes: 480, deepMinutes: 100))
        let r = try measured(calculator.compute(day: day, today: today, history: fourteenNights))
        #expect(r.missing.contains(.hrv))
    }

    @Test func sleepGoalChangesTheSleepFactor() throws {
        let today = NightSample(day: day, sdnnMs: 50, restingHeartRate: 50, sleep: .init(asleepMinutes: 420, deepMinutes: nil))
        let byDefault = try measured(calculator.compute(day: day, today: today, history: fourteenNights))
        // 87,5 la nuit dernière (7 h sur 8 h) ; 2 h 30 de dette (score 68,75) → 70 % × 87,5 + 30 % × 68,75.
        #expect(abs((byDefault.factors.first { $0.factor == .sleep }?.score ?? 0) - 81.875) < 1e-6)
        #expect(byDefault.insight?.sleepDebtMinutes == 150)
        let toGoal = try measured(calculator.compute(day: day, today: today, history: fourteenNights, sleepGoalMinutes: 420))
        #expect(toGoal.factors.first { $0.factor == .sleep }?.score == 100)
        #expect(toGoal.insight?.sleepDebtMinutes == 0)
    }
}
