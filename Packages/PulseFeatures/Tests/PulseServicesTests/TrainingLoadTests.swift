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
        let result = TrainingLoad.acwr(sessions: regularWeeks, historyStart: daysAgo(20), now: now, calendar: calendar)
        #expect(result == nil)
    }

    @Test func ratioOverFourWeeks() throws {
        let sessions = regularWeeks
        #expect(sessions.count == 16)
        let result = try #require(TrainingLoad.acwr(sessions: sessions, historyStart: daysAgo(40), now: now, calendar: calendar))
        #expect(result.acute == 1_680)
        #expect(result.chronic == 1_680)
        #expect(result.ratio == 1)
        #expect(result.zone == .optimal)
    }

    @Test func ridesAreCappedAtFive() throws {
        let ride = session(daysAgo: 1, kind: .ride, minutes: 60, rpe: 8)
        let result = try #require(TrainingLoad.acwr(sessions: [ride], historyStart: daysAgo(40), now: now, calendar: calendar))
        #expect(result.acute == 300)
    }

    /// Spec M4 §14.6 : une séance abandonnée compte, sans RPE noté (6 par défaut) ; une séance encore en cours, jamais.
    @Test func abandonedSessionsCountButNotInProgressOnes() throws {
        let sessions = [session(daysAgo: 1), session(daysAgo: 2, status: .inProgress), session(daysAgo: 3, rpe: nil, status: .abandoned)]
        let result = try #require(TrainingLoad.acwr(sessions: sessions, historyStart: daysAgo(40), now: now, calendar: calendar))
        #expect(result.acute == 420 + 360)
    }

    @Test func missingValuesFallBack() throws {
        let start = daysAgo(1)
        let noDuration = WorkoutSession(
            startedAt: start, endedAt: start.addingTimeInterval(45 * 60), kind: .run, source: .appleHealth, status: .completed,
            title: "Course", estimatedRPE: 5, createdAt: start, updatedAt: start)
        let noRPE = session(daysAgo: 2, minutes: 30, rpe: nil)
        let result = try #require(
            TrainingLoad.acwr(sessions: [noDuration, noRPE], historyStart: daysAgo(40), now: now, calendar: calendar))
        #expect(result.acute == 45 * 5 + 30 * 6)
    }

    @Test func oldestSessionStartsTheHistory() {
        let sessions = [session(daysAgo: 30), session(daysAgo: 1)]
        #expect(TrainingLoad.historyStart(sessions: sessions, onboardingCompletedAt: nil) == daysAgo(30))
        #expect(TrainingLoad.historyStart(sessions: sessions, onboardingCompletedAt: daysAgo(3)) == daysAgo(30))
        #expect(TrainingLoad.historyStart(sessions: sessions, onboardingCompletedAt: daysAgo(90)) == daysAgo(90))
        #expect(TrainingLoad.historyStart(sessions: [], onboardingCompletedAt: nil) == nil)
        #expect(TrainingLoad.acwr(sessions: sessions, historyStart: daysAgo(30), now: now, calendar: calendar) != nil)
        #expect(TrainingLoad.acwr(sessions: sessions, historyStart: nil, now: now, calendar: calendar) == nil)
    }

    /// Le début de l'historique se lit sur tout l'historique : avec lui, une tranche de 28 jours (l'accueil) donne le même
    /// ratio que toutes les séances (les Stats), même quand la tranche ne contient pas la plus ancienne séance.
    @Test func aSliceAndTheFullHistoryGiveTheSameRatio() throws {
        let imported = WorkoutSession(startedAt: daysAgo(60), kind: .strength, source: .hevy, status: .completed, title: "Hevy",
                                      overallRPE: 7, durationMinutes: 60, createdAt: daysAgo(60), updatedAt: daysAgo(60))
        let all = [imported] + regularWeeks
        let start = TrainingLoad.historyStart(sessions: all, onboardingCompletedAt: daysAgo(10))
        #expect(start == daysAgo(60))
        let slice = all.filter { $0.startedAt >= daysAgo(27, hour: 0) }
        let fromSlice = try #require(TrainingLoad.acwr(sessions: slice, historyStart: start, now: now, calendar: calendar))
        #expect(fromSlice == TrainingLoad.acwr(sessions: all, historyStart: start, now: now, calendar: calendar))
    }

    /// Les courses et les vélos importés d'Apple Santé datent d'avant Pulse : ils ne font pas reculer le début de
    /// l'historique, sinon la charge chronique d'un nouvel utilisateur ne tiendrait que d'eux.
    @Test func importedHealthWorkoutsDoNotStartTheHistory() {
        let runs = [50, 40, 30, 20, 10].map { days -> WorkoutSession in
            WorkoutSession(startedAt: daysAgo(days), kind: .run, source: .appleHealth, status: .completed, title: "Course",
                           durationMinutes: 45, estimatedRPE: 6, createdAt: daysAgo(days), updatedAt: daysAgo(days))
        }
        let sessions = runs + (0..<5).map { session(daysAgo: $0) }
        let start = TrainingLoad.historyStart(sessions: sessions, onboardingCompletedAt: daysAgo(5))
        #expect(start == daysAgo(5))
        #expect(TrainingLoad.acwr(sessions: sessions, historyStart: start, now: now, calendar: calendar) == nil)
        #expect(TrainingLoad.historyStart(sessions: runs, onboardingCompletedAt: nil) == nil)
    }
}
