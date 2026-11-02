import Foundation
import PulseDomain
import PulseServices
import Testing

struct TrainingLoadTests {
    private let now = TestClock.date("2026-11-02T08:00")
    private var calendar: Calendar { TestClock.calendar }

    private func daysAgo(_ days: Int, hour: Int = 18) -> Date {
        let day = calendar.date(byAdding: .day, value: -days, to: calendar.startOfDay(for: now)) ?? now
        return calendar.date(byAdding: .hour, value: hour, to: day) ?? day
    }

    private func session(daysAgo days: Int, kind: SessionKind = .strength, minutes: Double? = 60, rpe: Double? = 7,
                         status: SessionStatus = .completed) -> WorkoutSession {
        let start = daysAgo(days)
        return WorkoutSession(
            startedAt: start, endedAt: start.addingTimeInterval(3_600), kind: kind, source: .pulse, status: status, title: "Séance",
            overallRPE: rpe, durationMinutes: minutes, createdAt: start, updatedAt: start)
    }

    /// Quatre séances par semaine sur les 28 derniers jours : les jours 0, 1, 3 et 5 de chaque semaine.
    private var regularWeeks: [WorkoutSession] {
        (0..<28).filter { [0, 1, 3, 5].contains($0 % 7) }.map { session(daysAgo: $0) }
    }

    @Test func hiddenBeforeTwentyEightDays() {
        let result = TrainingLoad.acwr(sessions: regularWeeks, onboardingCompletedAt: daysAgo(20), now: now, calendar: calendar)
        #expect(result == nil)
    }

    @Test func ratioOverFourWeeks() throws {
        let sessions = regularWeeks
        #expect(sessions.count == 16)
        let result = try #require(TrainingLoad.acwr(sessions: sessions, onboardingCompletedAt: daysAgo(40), now: now, calendar: calendar))
        #expect(result.acute == 1_680)
        #expect(result.chronic == 1_680)
        #expect(result.ratio == 1)
        #expect(result.zone == .optimal)
    }

    @Test func ridesAreCappedAtFive() throws {
        let ride = session(daysAgo: 1, kind: .ride, minutes: 60, rpe: 8)
        let result = try #require(TrainingLoad.acwr(sessions: [ride], onboardingCompletedAt: daysAgo(40), now: now, calendar: calendar))
        #expect(result.acute == 300)
    }

    @Test func unfinishedSessionsDoNotCount() throws {
        let counted = session(daysAgo: 1)
        let sessions = [counted, session(daysAgo: 2, status: .inProgress), session(daysAgo: 3, status: .abandoned)]
        let result = try #require(TrainingLoad.acwr(sessions: sessions, onboardingCompletedAt: daysAgo(40), now: now, calendar: calendar))
        #expect(result.acute == 420)
    }

    @Test func missingValuesFallBack() throws {
        let start = daysAgo(1)
        let noDuration = WorkoutSession(
            startedAt: start, endedAt: start.addingTimeInterval(45 * 60), kind: .run, source: .appleHealth, status: .completed,
            title: "Course", estimatedRPE: 5, createdAt: start, updatedAt: start)
        let noRPE = session(daysAgo: 2, minutes: 30, rpe: nil)
        let result = try #require(
            TrainingLoad.acwr(sessions: [noDuration, noRPE], onboardingCompletedAt: daysAgo(40), now: now, calendar: calendar))
        #expect(result.acute == 45 * 5 + 30 * 6)
    }

    @Test func oldestSessionStartsTheHistory() {
        let oldest = session(daysAgo: 30)
        let result = TrainingLoad.acwr(sessions: [oldest, session(daysAgo: 1)], onboardingCompletedAt: nil, now: now, calendar: calendar)
        #expect(result != nil)
        #expect(TrainingLoad.acwr(sessions: [session(daysAgo: 1)], onboardingCompletedAt: nil, now: now, calendar: calendar) == nil)
    }
}
