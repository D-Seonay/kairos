import Foundation
import PulseDomain
import PulseServices
import Testing

struct BedtimeRegularityTests {
    private let calendar = TestClock.calendar

    private func dates(_ times: [String]) -> [Date] {
        times.enumerated().map { index, time in TestClock.date(String(format: "2026-11-%02dT%@", index + 1, time)) }
    }

    @Test func regularityIsTheMeanGapToTheMedian() {
        // Médiane 23:30 ; écarts 30, 0, 30, 0, 0 → 12 min → 10.
        let times = dates(["23:00", "23:30", "00:00", "23:30", "23:30"])
        #expect(BedtimeRegularity.minutes(fellAsleep: times, calendar: calendar) == 10)
    }

    @Test func fewerThanFiveNightsGiveNoRegularity() {
        #expect(BedtimeRegularity.minutes(fellAsleep: dates(["23:00", "23:30", "00:00", "23:30"]), calendar: calendar) == nil)
    }

    @Test func levelsFollowTheThresholds() {
        #expect(BedtimeRegularity.level(minutes: 30) == .regular)
        #expect(BedtimeRegularity.level(minutes: 35) == .fairlyRegular)
        #expect(BedtimeRegularity.level(minutes: 60) == .fairlyRegular)
        #expect(BedtimeRegularity.level(minutes: 65) == .irregular)
    }
}
