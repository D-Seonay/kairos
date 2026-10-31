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
        #expect(r.score == 100)
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
        #expect(abs(r.score - 87.125) < 1e-6)
        #expect(r.category == .normal)
        #expect(r.missing == [.hrv])
        #expect(r.calibration == .ready)
        #expect(r.factors.map(\.weight) == [0.5, 0.5])
        #expect(r.factors.map(\.factor) == [.restingHeartRate, .sleep])
        #expect(r.allowsProgressiveOverload == false)
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
        #expect(abs(r.score - 97.8125) < 1e-6)
    }

    @Test func twoMissingFactorsNeedsCheckIn() {
        let today = NightSample(day: day, sdnnMs: nil, restingHeartRate: nil, sleep: nil)
        let outcome = calculator.compute(day: day, today: today, history: [])
        #expect(outcome == .needsCheckIn(missing: [.hrv, .restingHeartRate, .sleep]))
    }

    @Test(arguments: [(2, 7, [Factor]()), (3, 4, [Factor.hrv])])
    func gapsInHistoryUseCalendarWindow(stride: Int, expectedNights: Int, expectedMissing: [Factor]) throws {
        let history = (1...42).map { offset in
            NightSample(day: TestCalendar.shift(day, by: -offset),
                        sdnnMs: offset.isMultiple(of: stride) ? 50 : nil, restingHeartRate: 50, sleep: nil)
        }
        let today = NightSample(day: day, sdnnMs: 50, restingHeartRate: 50, sleep: .init(asleepMinutes: 480, deepMinutes: 96))
        let r = try measured(calculator.compute(day: day, today: today, history: history))
        #expect(r.calibration == .calibrating(nights: expectedNights))
        #expect(r.missing == expectedMissing)
    }

    @Test func todaySDNNOutOfRangeIsMissing() throws {
        let today = NightSample(day: day, sdnnMs: 0, restingHeartRate: 49, sleep: .init(asleepMinutes: 480, deepMinutes: 100))
        let r = try measured(calculator.compute(day: day, today: today, history: fourteenNights))
        #expect(r.missing.contains(.hrv))
    }
}
