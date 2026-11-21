import Foundation
import PulseServices
import Testing

struct StatsPeriodTests {
    private let now = TestClock.date("2026-11-20T12:00")
    private var calendar: Calendar { TestClock.calendar }

    @Test func monthIntervalCoversThirtyCalendarDays() {
        let interval = StatsPeriod.month.interval(now: now, calendar: calendar)
        #expect(interval.start == TestClock.date("2026-10-22T00:00"))
        #expect(interval.end == TestClock.date("2026-11-21T00:00"))
        let previous = StatsPeriod.month.previousInterval(now: now, calendar: calendar)
        #expect(previous.start == TestClock.date("2026-09-22T00:00"))
        #expect(previous.end == TestClock.date("2026-10-22T00:00"))
    }

    /// Le passage à l'heure d'hiver (25 octobre 2026) allonge une journée de 24 h à 25 h : 30 jours restent 30 jours de calendrier.
    @Test func periodSpansDaylightSavingChange() {
        let interval = StatsPeriod.month.interval(now: now, calendar: calendar)
        #expect(interval.duration != 30 * 86_400)
        #expect(calendar.dateComponents([.day], from: interval.start, to: interval.end).day == 30)
        let previous = StatsPeriod.month.previousInterval(now: now, calendar: calendar)
        #expect(calendar.dateComponents([.day], from: previous.start, to: previous.end).day == 30)
    }

    @Test func daysAndTitles() {
        #expect(StatsPeriod.allCases.map(\.days) == [7, 30, 90, 365])
        #expect(StatsPeriod.allCases.map(\.title) == ["7 jours", "30 jours", "90 jours", "1 an"])
    }

    @Test func buckets() {
        #expect(StatsPeriod.year.chartBucket == .week)
        #expect(StatsPeriod.quarter.chartBucket == .day)
        #expect(StatsPeriod.week.loadBucket == .day)
        #expect(StatsPeriod.month.loadBucket == .week)
    }
}
