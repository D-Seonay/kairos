import Foundation
import PulseDomain
import PulseServices
import Testing

struct BaselineSummaryTests {
    private let calendar = TestClock.calendar
    private let today = TestClock.date("2026-11-10T00:00")

    private func night(daysAgo: Int, sdnn: Double? = nil, heartRate: Double? = nil, sleep: Int? = nil) -> NightSample {
        let day = calendar.date(byAdding: .day, value: -daysAgo, to: today) ?? today
        return NightSample(day: day, sdnnMs: sdnn, restingHeartRate: heartRate,
                           sleep: sleep.map { SleepSummary(asleepMinutes: $0, deepMinutes: nil) })
    }

    @Test func baselineFromHandmadeNights() {
        let nights = [
            night(daysAgo: 1, sdnn: 40, heartRate: 48, sleep: 420),
            night(daysAgo: 2, sdnn: 50, heartRate: 50, sleep: 480),
            night(daysAgo: 3, sdnn: 60, heartRate: 52),
            night(daysAgo: 20, sleep: 300),
            night(daysAgo: 0)
        ]
        let summary = BaselineSummary.make(nights: nights, day: today, calendar: calendar)
        #expect(summary.hrvMeanMs == 50)
        #expect(summary.hrvDeviationMs == 10)
        #expect(summary.restingHeartRateMean == 50)
        #expect(summary.restingHeartRateDeviation == 2)
        #expect(summary.sleepMeanMinutes == 450)
        #expect(summary.nightsAnalyzed == 4)
    }

    @Test func heartRateUsesSevenDaysOnly() {
        let nights = [night(daysAgo: 7, heartRate: 50), night(daysAgo: 8, heartRate: 80), night(daysAgo: 6, heartRate: 54)]
        let summary = BaselineSummary.make(nights: nights, day: today, calendar: calendar)
        #expect(summary.restingHeartRateMean == 52)
    }

    @Test func singleValueGivesNoDeviation() {
        let summary = BaselineSummary.make(nights: [night(daysAgo: 1, sdnn: 45, heartRate: 50)], day: today, calendar: calendar)
        #expect(summary.hrvMeanMs == nil && summary.hrvDeviationMs == nil)
        #expect(summary.restingHeartRateMean == nil && summary.restingHeartRateDeviation == nil)
        #expect(summary.nightsAnalyzed == 1)
    }

    @Test func invalidSDNNIsIgnored() {
        let nights = [night(daysAgo: 1, sdnn: 40), night(daysAgo: 2, sdnn: 500), night(daysAgo: 3, sdnn: 60)]
        let summary = BaselineSummary.make(nights: nights, day: today, calendar: calendar)
        #expect(summary.hrvMeanMs == 50)
        #expect(summary.nightsAnalyzed == 2)
    }

    @Test func noNights() {
        let summary = BaselineSummary.make(nights: [], day: today, calendar: calendar)
        #expect(summary.hrvMeanMs == nil && summary.sleepMeanMinutes == nil)
        #expect(summary.nightsAnalyzed == 0)
    }
}
