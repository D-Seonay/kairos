import Foundation
import PulseDomain
import PulseServices
import Testing

struct RecentExercisesTests {
    private let now = TestClock.date("2026-11-30T12:00")

    private func session(daysAgo: Int, _ references: [ExerciseReference]) throws -> WorkoutSession {
        let start = try #require(TestClock.calendar.date(byAdding: .day, value: -daysAgo, to: now))
        let sets = references.enumerated().map { index, reference in
            WorkoutSet(order: index, exercise: reference, exerciseName: "x", setType: .working)
        }
        return WorkoutSession(startedAt: start, kind: .strength, source: .pulse, status: .completed, title: "Test", sets: sets,
                              createdAt: start, updatedAt: start)
    }

    @Test func recentExercisesComeFromTheLast30Days() throws {
        let bench = ExerciseReference.content(id: "bench-press-barbell")
        let row = ExerciseReference.content(id: "barbell-row")
        let squat = ExerciseReference.content(id: "back-squat-barbell")
        let old = ExerciseReference.content(id: "deadlift-barbell")
        // Données dans le désordre : l'ordre vient des dates, pas de la liste.
        let sessions = [try session(daysAgo: 10, [row, bench]), try session(daysAgo: 31, [old]),
                        try session(daysAgo: 2, [bench, squat, bench])]
        let found = RecentExercises.references(in: sessions, now: now, calendar: TestClock.calendar)
        #expect(found == [bench, squat, row])
        #expect(RecentExercises.references(in: sessions, now: now, calendar: TestClock.calendar, days: 3) == [bench, squat])
    }

    @Test func noSessionGivesNoReference() {
        #expect(RecentExercises.references(in: [], now: now, calendar: TestClock.calendar).isEmpty)
    }
}
