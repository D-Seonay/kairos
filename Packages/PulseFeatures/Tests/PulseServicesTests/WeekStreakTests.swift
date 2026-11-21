import Foundation
import PulseDomain
import PulseServices
import Testing

struct WeekStreakTests {
    private typealias Fixture = PlanningFixtures
    private let calendar = TestClock.calendar
    private let now = TestClock.date("2026-11-18T12:00")

    /// `count` séances de musculation dans la semaine du lundi `monday`, une par jour à partir du lundi.
    private func week(_ monday: String, count: Int, kind: SessionKind = .strength) -> [WorkoutSession] {
        let start = TestClock.date("\(monday)T18:00")
        return (0..<count).map { offset in
            var session = Fixture.session("\(monday)T18:00", kind: kind)
            session.startedAt = calendar.date(byAdding: .day, value: offset, to: start) ?? start
            return session
        }
    }

    private func summary(_ sessions: [WorkoutSession], target: Int = 3, historyStart: String? = "2026-09-01T08:00") -> StreakSummary {
        WeekStreak.summary(sessions: sessions, target: target, historyStart: historyStart.map(TestClock.date), now: now,
                           calendar: calendar)
    }

    @Test func consecutiveSuccessfulWeeksUntilLastWeek() {
        let sessions = week("2026-10-26", count: 3) + week("2026-11-02", count: 3) + week("2026-11-09", count: 4)
        let result = summary(sessions)
        #expect(result.streak == 3)
        #expect(result.weeks.count == WeekStreak.pillarWeeks)
        #expect(result.currentWeek?.isCurrent == true && result.currentWeek?.count == .zero)
        #expect(result.weeks.suffix(4).map(\.isSuccess) == [true, true, true, false])
    }

    @Test func currentWeekCountsOnceReached() {
        let sessions = week("2026-11-09", count: 3) + week("2026-11-16", count: 3)
        #expect(summary(sessions).streak == 2)
    }

    @Test func aMissedWeekBreaksTheStreak() {
        let sessions = week("2026-10-26", count: 3) + week("2026-11-02", count: 2) + week("2026-11-09", count: 3)
        #expect(summary(sessions).streak == 1)
    }

    @Test func runsCountRidesAndAbandonsDoNot() {
        var sessions = week("2026-11-09", count: 2) + week("2026-11-12", count: 1, kind: .run)
        #expect(summary(sessions).streak == 1)
        sessions = week("2026-11-09", count: 2) + week("2026-11-12", count: 1, kind: .ride)
        #expect(summary(sessions).streak == 0)
        var abandoned = week("2026-11-12", count: 1)
        abandoned[0].status = .abandoned
        #expect(summary(week("2026-11-09", count: 2) + abandoned).streak == 0)
    }

    @Test func streakStopsAtTheHistoryStart() {
        let sessions = week("2026-11-02", count: 3) + week("2026-11-09", count: 3)
        #expect(summary(sessions, target: 1, historyStart: "2026-11-04T08:00").streak == 2)
        #expect(summary(sessions, historyStart: nil).streak == 0)
    }

    @Test func targetComesFromTheProgramThenTheProfile() {
        #expect(WeekStreak.target(program: Fixture.program(), profile: nil) == 5)
        #expect(WeekStreak.target(program: nil, profile: UserProfile(trainingDaysPerWeek: 4)) == 4)
        #expect(WeekStreak.target(program: nil, profile: nil) == 1)
    }

    @Test func progressIsCapped() {
        let week = StreakWeek(weekStart: now, count: 7, target: 5, isCurrent: true)
        #expect(week.progress == 1 && week.isSuccess)
    }

    private func best(_ sessions: [WorkoutSession], target: Int = 3, historyStart: String? = "2026-08-01T08:00") -> BestStreak? {
        WeekStreak.best(sessions: sessions, target: target, historyStart: historyStart.map(TestClock.date), now: now,
                        calendar: calendar)
    }

    @Test func bestFindsLongestRunAnywhere() {
        // Cinq semaines réussies depuis le 17 août, une manquée (21 septembre), puis deux.
        let mondays = ["2026-08-17", "2026-08-24", "2026-08-31", "2026-09-07", "2026-09-14", "2026-09-28", "2026-10-05"]
        let sessions = mondays.flatMap { week($0, count: 3) }
        let result = best(sessions)
        #expect(result?.weeks == 5)
        #expect(result?.firstWeek == TestClock.date("2026-08-17T00:00"))
        #expect(result?.lastWeek == TestClock.date("2026-09-14T00:00"))
    }

    @Test func bestTieKeepsTheMostRecentRun() {
        let sessions = ["2026-09-07", "2026-09-14", "2026-10-12", "2026-10-19"].flatMap { week($0, count: 3) }
        let result = best(sessions)
        #expect(result?.weeks == 2)
        #expect(result?.firstWeek == TestClock.date("2026-10-12T00:00"))
    }

    @Test func bestCountsTheCurrentWeekOnlyOnceReached() {
        let past = week("2026-11-02", count: 3) + week("2026-11-09", count: 3)
        #expect(best(past + week("2026-11-16", count: 2))?.weeks == 2)
        let reached = best(past + week("2026-11-16", count: 3))
        #expect(reached?.weeks == 3)
        #expect(reached?.lastWeek == TestClock.date("2026-11-16T00:00"))
    }

    @Test func bestIgnoresWeeksBeforeTheHistoryStart() {
        let sessions = week("2026-10-26", count: 3) + week("2026-11-02", count: 3)
        #expect(best(sessions, historyStart: "2026-11-04T08:00")?.weeks == 1)
    }

    @Test func bestIsNilWithoutSuccess() {
        #expect(best(week("2026-11-09", count: 2)) == nil)
        #expect(best([]) == nil)
        #expect(best(week("2026-11-09", count: 3), historyStart: nil) == nil)
    }
}
