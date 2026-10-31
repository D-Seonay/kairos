import Foundation
import Testing
@testable import PulseRecoveryEngine

@Suite struct LoadCalculatorTests {
    let calculator = LoadCalculator(calendar: TestCalendar.paris)
    let day = TestCalendar.day(2026, 11, 28)
    let start = TestCalendar.day(2026, 11, 1)

    /// Une séance de 60 min à RPE 7 (charge 420) chaque semaine, offsets 0, 7, 14, 21.
    var weeklySessions: [LoadSession] {
        [0, 7, 14, 21].map { LoadSession(date: TestCalendar.shift(day, by: -$0), minutes: 60, rpe: 7) }
    }

    @Test func steadyLoadIsOptimal() {
        let r = calculator.acwr(sessions: weeklySessions, asOf: day, historyStart: start)
        #expect(r?.acute == 420)
        #expect(r?.chronic == 420)
        #expect(r?.ratio == 1)
        #expect(r?.zone == .optimal)
    }

    @Test func spikeIsRisk() throws {
        let sessions = weeklySessions + [LoadSession(date: TestCalendar.date(2026, 11, 28, 18, 0), minutes: 60, rpe: 8)]
        let r = try #require(calculator.acwr(sessions: sessions, asOf: day, historyStart: start))
        #expect(r.acute == 900)
        #expect(r.chronic == 540)
        #expect(abs(r.ratio - 1.6667) < 1e-4)
        #expect(r.zone == .risk)
    }

    @Test func needsTwentyEightDaysOfHistory() {
        let lateStart = TestCalendar.shift(day, by: -20)
        #expect(calculator.acwr(sessions: weeklySessions, asOf: day, historyStart: lateStart) == nil)
    }

    @Test(arguments: [
        (0.79, ACWRZone.undertraining), (0.8, .optimal), (1.3, .optimal),
        (1.31, .elevated), (1.49, .elevated), (1.5, .risk),
    ])
    func zoneBoundaries(ratio: Double, expected: ACWRZone) {
        #expect(ACWRZone(ratio: ratio) == expected)
    }

    @Test func noChronicLoadReturnsNil() {
        #expect(calculator.acwr(sessions: [], asOf: day, historyStart: start) == nil)
    }

    @Test func sessionLoadIsMinutesTimesRPE() {
        #expect(LoadSession(date: day, minutes: 45, rpe: 6).load == 270)
    }
}
