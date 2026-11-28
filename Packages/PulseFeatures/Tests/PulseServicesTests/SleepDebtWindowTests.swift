import Foundation
import PulseDomain
import PulseServices
import Testing

/// La dette de sommeil des 7 nuits (#117), lue sur les nuits de l'écran Nuit et du rappel du coucher.
struct SleepDebtWindowTests {
    private let calendar = TestClock.calendar

    private func night(_ day: String, asleep: Int) -> NightSleep {
        let wake = TestClock.date("\(day)T07:00")
        return NightSleep(day: TestClock.date("\(day)T00:00"), fellAsleep: wake.addingTimeInterval(-Double(asleep) * 60), wokeUp: wake,
                          segments: [], otherBlocks: [], asleepMinutes: asleep, deepMinutes: 0, coreMinutes: 0, remMinutes: 0,
                          unspecifiedMinutes: asleep, awakeMinutes: 0, awakenings: 0, hasStages: false)
    }

    /// Trois nuits de 5 h 30, puis une de 8 h : 150 min × (6 + 5 + 4) / 7 de dette.
    @Test func threeShortNightsThenAGoodOne() {
        let nights = [night("2026-11-20", asleep: 480), night("2026-11-19", asleep: 330), night("2026-11-18", asleep: 330),
                      night("2026-11-17", asleep: 330)]
        let debt = SleepDebtWindow.minutes(endingAt: TestClock.date("2026-11-20T00:00"), nights: nights, goalMinutes: 480,
                                           calendar: calendar)
        #expect(debt == 321)
    }

    @Test func nightsBeyondSevenDaysAreIgnored() {
        let nights = [night("2026-11-20", asleep: 480), night("2026-11-13", asleep: 0)]
        #expect(SleepDebtWindow.minutes(endingAt: TestClock.date("2026-11-20T00:00"), nights: nights, goalMinutes: 480,
                                        calendar: calendar) == 0)
    }

    @Test func unknownEndingNightGivesNoDebt() {
        let nights = [night("2026-11-19", asleep: 300)]
        #expect(SleepDebtWindow.minutes(endingAt: TestClock.date("2026-11-20T00:00"), nights: nights, goalMinutes: 480,
                                        calendar: calendar) == nil)
    }
}
