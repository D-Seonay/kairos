import Foundation
import PulseDomain
import PulseRecoveryEngine
import PulseServices
import Testing

struct ProfileServiceTests {
    private func repositories(withScoreToday: Bool = true, estimatedToday: Bool = false) async throws -> StatsRepositories {
        let repositories = StatsRepositories()
        let program = StatsFixtures.program()
        try await repositories.programs.save(program)
        try await repositories.profiles.save(UserProfile(firstName: "Mathéo", restWeekdays: [.friday, .sunday],
                                                         onboardingCompletedAt: StatsFixtures.monday(ofWeek: 18),
                                                         activeProgramID: program.id))
        // Trois semaines de 4 séances de musculation (la dernière est celle du 16 novembre, déjà réussie le jeudi).
        var sessions: [WorkoutSession] = []
        for week in 18...20 {
            for (offset, lifts) in [StatsFixtures.push, StatsFixtures.pull, StatsFixtures.legs, StatsFixtures.push].enumerated() {
                let start = StatsFixtures.day(offset, ofWeek: week)
                guard start < StatsFixtures.now else { continue }
                sessions.append(StatsFixtures.strengthSession(lifts, title: "Séance", start: start, week: week, programID: program.id))
            }
        }
        sessions.append(StatsFixtures.ride(start: StatsFixtures.day(6, ofWeek: 18, hour: 10)))
        for session in sessions { try await repositories.workouts.save(session) }
        let directory = ExerciseDirectory(library: .bundled, userExercises: [])
        let book = RecordBook.compute(sessions: sessions, loadKind: directory.loadKind(of:), now: StatsFixtures.now)
        try await repositories.records.replaceAll(with: book.records)
        let today = TestClock.calendar.startOfDay(for: StatsFixtures.now)
        let yesterday = TestClock.calendar.date(byAdding: .day, value: -1, to: today) ?? today
        for day in withScoreToday ? [yesterday, today] : [yesterday] {
            let score = day == today ? 82.0 : 60.0
            try await repositories.recoveries.save(DailyRecovery(
                day: day, score: score, category: RecoveryCategory(score: score), isEstimated: day == today && estimatedToday,
                hrvScore: score,
                restingHeartRateScore: score, sleepScore: score, calibration: .ready, createdAt: day, updatedAt: day))
        }
        return repositories
    }

    @Test func summaryOnSmallHistory() async throws {
        let summary = try await repositories().profileService().summary()

        // 4 + 4 + 4 séances comptées (la semaine en cours s'arrête au jeudi 20) ; le vélo ne compte pas.
        #expect(summary.firstName == "Mathéo")
        #expect(summary.sessionsTotal == 12)
        #expect(summary.firstSession == StatsFixtures.day(0, ofWeek: 18))
        #expect(summary.streakWeeks == 3)
        #expect(summary.morningScore == 82 && !summary.morningScoreIsEstimated)
        #expect(summary.mainLifts.first?.exercise == .content(id: "back-squat-barbell"))
        #expect(summary.mainLifts.map(\.exercise) == [
            .content(id: "back-squat-barbell"), .content(id: "bench-press-barbell"),
            .content(id: "deadlift-barbell"), .content(id: "overhead-press-barbell")
        ])
        #expect(summary.runs.count == 3)
        #expect(summary.badges.earned.map(\.kind) == [.sessions(count: 10)])
        #expect(summary.badges.next.first?.kind == .streak(weeks: 4))
    }

    @Test func noScoreToday() async throws {
        let summary = try await repositories(withScoreToday: false).profileService().summary()

        #expect(summary.morningScore == nil && !summary.morningScoreIsEstimated)
    }

    @Test func estimatedScoreToday() async throws {
        let summary = try await repositories(estimatedToday: true).profileService().summary()

        #expect(summary.morningScore == 82)
        #expect(summary.morningScoreIsEstimated)
    }

    @Test func emptyProfile() async throws {
        let summary = try await StatsRepositories().profileService().summary()

        #expect(summary.firstName == nil)
        #expect(summary.sessionsTotal == 0 && summary.firstSession == nil && summary.streakWeeks == 0)
        #expect(summary.mainLifts.isEmpty)
        #expect(summary.runs.count == 3)
        #expect(summary.badges.earned.isEmpty && summary.badges.next.count == 3)
    }
}
