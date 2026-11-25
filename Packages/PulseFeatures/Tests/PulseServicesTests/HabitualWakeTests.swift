import Foundation
import PulseDomain
import PulseServices
import Testing

struct HabitualWakeTests {
    private let calendar = TestClock.calendar

    private func dates(_ entries: [String]) -> [Date] { entries.map { TestClock.date($0) } }

    /// 5 réveils de semaine (16 au 20 novembre 2026, du lundi au vendredi).
    private var weekdayWakes: [Date] {
        dates(["2026-11-16T07:00", "2026-11-17T07:10", "2026-11-18T06:50", "2026-11-19T07:05", "2026-11-20T07:20"])
    }

    @Test func eachGroupHasItsOwnMedian() {
        let wakes = weekdayWakes + dates(["2026-11-21T09:30", "2026-11-22T10:00", "2026-11-14T09:00"])
        #expect(HabitualWake.minutes(wokeUp: wakes, weekend: false, calendar: calendar) == 425)
        #expect(HabitualWake.minutes(wokeUp: wakes, weekend: true, calendar: calendar) == 570)
    }

    @Test func smallGroupFallsBackToAllNights() {
        let wakes = weekdayWakes + dates(["2026-11-21T09:30", "2026-11-22T10:00"])
        #expect(HabitualWake.minutes(wokeUp: wakes, weekend: true, calendar: calendar) == 430)
    }

    @Test func fewerThanFiveNightsGiveNothing() {
        let wakes = dates(["2026-11-16T07:00", "2026-11-17T07:10", "2026-11-21T09:30", "2026-11-22T10:00"])
        #expect(HabitualWake.minutes(wokeUp: wakes, weekend: false, calendar: calendar) == nil)
        #expect(HabitualWake.minutes(wokeUp: wakes, weekend: true, calendar: calendar) == nil)
    }
}
