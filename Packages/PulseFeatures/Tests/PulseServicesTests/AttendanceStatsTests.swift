import Foundation
import PulseDomain
import PulseServices
import Testing

struct AttendanceStatsTests {
    /// Mercredi 18 novembre 2026 : la semaine en cours commence le lundi 16.
    private let now = TestClock.date("2026-11-18T12:00")
    private var calendar: Calendar { TestClock.calendar }

    private func day(_ daysAgo: Int, hour: Int = 18) -> Date {
        let start = calendar.date(byAdding: .day, value: -daysAgo, to: calendar.startOfDay(for: now)) ?? now
        return calendar.date(byAdding: .hour, value: hour, to: start) ?? start
    }

    private func session(daysAgo: Int, hour: Int = 18, minutes: Double? = 60, rpe: Double = 5, kind: SessionKind = .strength,
                         status: SessionStatus = .completed) -> WorkoutSession {
        let start = day(daysAgo, hour: hour)
        return WorkoutSession(startedAt: start, endedAt: minutes.map { start.addingTimeInterval($0 * 60) }, kind: kind,
                              source: .pulse, status: status, title: "Séance", overallRPE: rpe, durationMinutes: minutes,
                              createdAt: start, updatedAt: start)
    }

    private func stats(_ sessions: [WorkoutSession], target: Int = 1, historyStart: Date? = TestClock.date("2026-01-05T08:00"),
                       period: StatsPeriod = .month) -> AttendanceStats {
        AttendanceStats.make(sessions: sessions, target: target, historyStart: historyStart, period: period, now: now,
                             calendar: calendar)
    }

    @Test func matrixHasSixteenWeeksOfSevenDays() {
        let result = stats([session(daysAgo: 0)])
        #expect(result.weeks.count == AttendanceStats.matrixWeeks)
        #expect(result.weeks.allSatisfy { $0.count == 7 })
        #expect(result.weeks.last?.first?.date == TestClock.date("2026-11-16T00:00"))
        #expect(result.weeks.first?.first?.date == TestClock.date("2026-08-03T00:00"))
        let today = calendar.startOfDay(for: now)
        let all = result.weeks.flatMap { $0 }
        #expect(all.filter(\.isFuture).count == 4)
        #expect(all.allSatisfy { $0.isFuture == ($0.date > today) })
    }

    @Test func levelsFollowQuartiles() {
        // Charges quotidiennes 100, 200, 300 et 400 (minutes × RPE).
        let sessions = [
            session(daysAgo: 6, minutes: 20, rpe: 5), session(daysAgo: 5, minutes: 40, rpe: 5),
            session(daysAgo: 4, minutes: 60, rpe: 5), session(daysAgo: 3, minutes: 80, rpe: 5)
        ]
        let result = stats(sessions)
        func level(_ daysAgo: Int) -> Int? {
            let date = calendar.startOfDay(for: day(daysAgo))
            return result.weeks.flatMap { $0 }.first { $0.date == date }?.level
        }
        #expect([6, 5, 4, 3].map(level) == [1, 2, 3, 4])
        #expect(level(2) == 0)
    }

    @Test func aDayWithoutComputableLoadGetsLevelOne() {
        let result = stats([session(daysAgo: 1, minutes: nil), session(daysAgo: 2, minutes: 60)])
        let levels = result.weeks.flatMap { $0 }.filter { $0.level > 0 }.map(\.level)
        #expect(levels.sorted() == [1, 1])
    }

    /// Le vélo apparaît dans la matrice sans compter pour la série ni pour les tuiles ; un abandon n'apparaît pas.
    @Test func matrixShowsRidesWithoutCountingThemForTheStreak() {
        let sessions = [session(daysAgo: 1, kind: .ride), session(daysAgo: 2, status: .abandoned),
                        session(daysAgo: 3, kind: .ride, status: .abandoned)]
        let result = stats(sessions)
        let active = result.weeks.flatMap { $0 }.filter { $0.level > 0 }
        #expect(active.map(\.date) == [calendar.startOfDay(for: day(1))])
        #expect(result.streak.weeks.allSatisfy { $0.count < 1 } && result.sessionsTotal == 0 && result.sessionsInPeriod == 0)
        #expect(result.firstSession == nil)
    }

    @Test func usualHourIsTheMostFrequent() {
        let sessions = [18, 18, 18, 7, 7].enumerated().map { session(daysAgo: $0.offset, hour: $0.element) }
        #expect(stats(sessions).usualHour == 18)
    }

    @Test func usualHourTieKeepsTheEarliest() {
        let sessions = [session(daysAgo: 1, hour: 19), session(daysAgo: 2, hour: 7)]
        #expect(stats(sessions).usualHour == 7)
    }

    @Test func periodAndTotalsCountTheRightSessions() {
        let sessions = [session(daysAgo: 1, minutes: 60), session(daysAgo: 10, minutes: 30), session(daysAgo: 29, minutes: nil),
                        session(daysAgo: 30, minutes: 90), session(daysAgo: 100, minutes: 45), session(daysAgo: 2, kind: .ride)]
        let result = stats(sessions)
        #expect(result.sessionsInPeriod == 3)
        #expect(result.sessionsTotal == 5)
        #expect(result.firstSession == day(100))
        // La séance sans durée est ignorée de la moyenne.
        #expect(result.averageMinutes == 45)
    }

    @Test func regularityIgnoresWeeksBeforeHistory() {
        // Période de 90 jours, historique depuis le lundi 2 novembre : semaines du 2, du 9 (réussies) et en cours (échouée,
        // exclue) ; celles d'avant sont ignorées.
        let sessions = [session(daysAgo: 14), session(daysAgo: 8)]
        let result = stats(sessions, historyStart: TestClock.date("2026-11-04T08:00"), period: .quarter)
        #expect(result.regularity == 1)
        let withMiss = stats([session(daysAgo: 8)], historyStart: TestClock.date("2026-11-04T08:00"), period: .quarter)
        #expect(withMiss.regularity == 0.5)
    }

    @Test func regularityCountsTheCurrentWeekOnceSuccessful() {
        let result = stats([session(daysAgo: 0)], historyStart: TestClock.date("2026-11-04T08:00"))
        #expect(result.regularity == 1.0 / 3.0)
    }

    @Test func regularityFollowsThePeriod() {
        // 7 jours : les semaines du 9 et du 16 ; la semaine du 9 réussie, la semaine en cours exclue.
        let result = stats([session(daysAgo: 8)], period: .week)
        #expect(result.regularity == 1)
    }

    @Test func emptyHistory() {
        let result = stats([], historyStart: nil)
        #expect(result.weeks.count == 16 && result.weeks.allSatisfy { $0.count == 7 && $0.allSatisfy { $0.level == 0 } })
        #expect(result.sessionsInPeriod == 0 && result.sessionsTotal == 0)
        #expect(result.firstSession == nil && result.averageMinutes == nil && result.usualHour == nil)
        #expect(result.regularity == nil && result.best == nil && result.streak.streak == 0)
    }
}
