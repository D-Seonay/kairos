import Foundation
import PulseDomain
import PulseServices
import Testing

struct BadgesTests {
    private let calendar = TestClock.calendar
    /// Un mercredi : la semaine en cours est celle du lundi 16 novembre 2026.
    private let now = TestClock.date("2026-11-18T12:00")
    private let target = 2

    /// `count` séances de musculation, une par jour à 18 h à partir du lundi `monday`.
    private func week(_ monday: String, count: Int, kind: SessionKind = .strength) -> [WorkoutSession] {
        let start = TestClock.date("\(monday)T18:00")
        return (0..<count).map { offset in
            var session = PlanningFixtures.session("\(monday)T18:00", kind: kind)
            session.startedAt = calendar.date(byAdding: .day, value: offset, to: start) ?? start
            return session
        }
    }

    /// Les lundis des `count` semaines qui précèdent la semaine du 16 novembre 2026, de la plus ancienne à la plus récente.
    private func mondays(before count: Int) -> [Date] {
        let current = WeekSchedule.weekStart(of: now, calendar: calendar)
        return (1...count).reversed().compactMap { calendar.date(byAdding: .weekOfYear, value: -$0, to: current) }
    }

    private func sessions(overWeeks count: Int, perWeek: Int = 2) -> [WorkoutSession] {
        mondays(before: count).flatMap { monday in
            (0..<perWeek).map { offset -> WorkoutSession in
                var session = PlanningFixtures.session("2026-01-05T18:00")
                session.startedAt = calendar.date(byAdding: .hour, value: 18 + offset * 24, to: monday) ?? monday
                return session
            }
        }
    }

    private func shelf(_ sessions: [WorkoutSession], historyStart: Date?) -> BadgeShelf {
        Badges.make(sessions: sessions, target: target, historyStart: historyStart, now: now, calendar: calendar)
    }

    @Test func streakBadgesDateTheirFirstRun() {
        let all = sessions(overWeeks: 9)
        let mondays = mondays(before: 9)
        let result = shelf(all, historyStart: all.map(\.startedAt).min())

        let four = result.earned.first { $0.kind == .streak(weeks: 4) }
        let eight = result.earned.first { $0.kind == .streak(weeks: 8) }
        // La 4e semaine est réussie par sa 2e séance (mardi 18 h), la 8e de même.
        #expect(four?.earnedAt == calendar.date(byAdding: .hour, value: 42, to: mondays[3]))
        #expect(eight?.earnedAt == calendar.date(byAdding: .hour, value: 42, to: mondays[7]))
        #expect(result.earned.contains { $0.kind == .streak(weeks: 12) } == false)
        #expect(result.next.first?.kind == .streak(weeks: 12))
        #expect(result.next.first?.current == 9)
    }

    @Test func aBrokenRunRestartsTheCount() {
        var all = sessions(overWeeks: 7)
        // La 4e semaine ne compte plus qu'une séance : 3 d'affilée, une manquée, puis 3.
        let fourth = mondays(before: 7)[3]
        all.removeAll { WeekSchedule.weekStart(of: $0.startedAt, calendar: calendar) == fourth }
        let result = shelf(all, historyStart: all.map(\.startedAt).min())

        #expect(result.earned.contains { $0.kind == .streak(weeks: 4) } == false)
        #expect(result.next.first?.current == 3)
    }

    @Test func sessionBadgesDateTheNthSession() {
        let all = (0..<12).map { index -> WorkoutSession in
            var session = PlanningFixtures.session("2026-11-02T08:00")
            session.startedAt = calendar.date(byAdding: .day, value: index, to: TestClock.date("2026-10-01T08:00")) ?? .now
            return session
        }
        let result = shelf(all.shuffled(), historyStart: nil)

        let ten = result.earned.first { $0.kind == .sessions(count: 10) }
        #expect(ten?.earnedAt == all[9].startedAt)
        let next = result.next.first { $0.kind == .sessions(count: 50) }
        #expect(next?.current == 12)
        #expect(next?.earnedAt == nil)
        // Sans début d'historique, aucun badge de série ni de mois.
        #expect(result.earned.map(\.kind) == [.sessions(count: 10)])
    }

    @Test func firstFullMonthNeedsFourSuccessfulWeeks() {
        // Octobre 2026 a 4 lundis (5, 12, 19, 26) : 3 semaines réussies sur 4.
        let october = ["2026-10-05", "2026-10-12", "2026-10-26"].flatMap { week($0, count: 2) }
        let almost = shelf(october, historyStart: october.first?.startedAt)
        #expect(almost.earned.contains { $0.kind == .firstFullMonth } == false)
        let pending = almost.next.first { $0.kind == .firstFullMonth }
        #expect(pending?.current == 3 && pending?.goal == 4)

        // Avec la semaine du 19 octobre, le mois est complet : la 4e semaine réussie (26 octobre) le date.
        let complete = october + week("2026-10-19", count: 2)
        let done = shelf(complete, historyStart: complete.map(\.startedAt).min())
        let badge = done.earned.first { $0.kind == .firstFullMonth }
        #expect(badge?.earnedAt == TestClock.date("2026-10-27T18:00"))
        #expect(done.next.contains { $0.kind == .firstFullMonth } == false)
    }

    @Test func aWeekBelongsToTheMonthOfItsMonday() {
        // La semaine du lundi 28 septembre finit en octobre : elle compte pour septembre, qui a alors 4 semaines réussies.
        let september = ["2026-09-07", "2026-09-14", "2026-09-21", "2026-10-05"].flatMap { week($0, count: 2) }
        let before = shelf(september, historyStart: september.map(\.startedAt).min())
        #expect(before.earned.contains { $0.kind == .firstFullMonth } == false)

        let withEdge = september + week("2026-09-28", count: 2)
        let result = shelf(withEdge, historyStart: withEdge.map(\.startedAt).min())
        #expect(result.earned.first { $0.kind == .firstFullMonth }?.earnedAt == TestClock.date("2026-09-29T18:00"))
    }

    @Test func ridesDoNotCount() {
        let rides = week("2026-11-09", count: 2, kind: .ride) + week("2026-11-02", count: 2, kind: .ride)
        let result = shelf(rides, historyStart: TestClock.date("2026-11-02T08:00"))

        #expect(result.earned.isEmpty)
        #expect(result.next.first { $0.kind == .sessions(count: 10) }?.current == 0)
        #expect(result.next.first { $0.kind == .streak(weeks: 4) }?.current == 0)
    }

    @Test func emptyHistory() {
        let result = shelf([], historyStart: nil)

        #expect(result.earned.isEmpty)
        #expect(result.next.map(\.kind) == [.streak(weeks: 4), .sessions(count: 10), .firstFullMonth])
        #expect(result.next.allSatisfy { $0.current == 0 && $0.progress == 0 && $0.earnedAt == nil })
    }

    @Test func earnedBadgesAreChronological() {
        let all = sessions(overWeeks: 9)
        let result = shelf(all, historyStart: all.map(\.startedAt).min())
        let dates = result.earned.compactMap(\.earnedAt)

        #expect(dates == dates.sorted())
        #expect(result.earned.count >= 3)
    }

    @Test func progressIsCappedAtOne() {
        #expect(Badge(kind: .streak(weeks: 4), earnedAt: nil, current: 9, goal: 4).progress == 1)
        #expect(Badge(kind: .streak(weeks: 4), earnedAt: nil, current: 1, goal: 4).progress == 0.25)
    }
}
