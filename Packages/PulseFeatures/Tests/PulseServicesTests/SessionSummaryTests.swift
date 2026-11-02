import Foundation
import PulseContent
import PulseDomain
import PulseServices
import Testing

struct SessionSummaryTests {
    private let library = ContentLibrary.bundled
    private var directory: ExerciseDirectory { ExerciseDirectory(library: library, userExercises: []) }

    private func ppl3Day(_ index: Int) throws -> RoutineDay {
        let template = try #require(library.programTemplate(id: "ppl-3"))
        return Program(template: template, now: TestClock.date("2026-11-02T08:00")).days[index]
    }

    private func exercise(_ id: String, sets: Int, rest: Int, group: Int? = nil, order: Int = 0, rpe: Double = 8) -> RoutineExercise {
        RoutineExercise(order: order, exercise: .content(id: id), sets: sets, repsMin: 8, repsMax: 10, targetRPE: rpe,
                        restSeconds: rest, supersetGroup: group)
    }

    private func day(_ exercises: [RoutineExercise]) -> RoutineDay {
        RoutineDay(order: 0, name: "Test", kind: .strength, exercises: exercises)
    }

    @Test func pushSummary() throws {
        let summary = SessionSummary.make(day: try ppl3Day(0), directory: directory)
        #expect(summary.setCount == 19 && summary.estimatedMinutes == 35 && summary.maxRPE == 8)
        #expect(summary.topMuscles == [.chest, .triceps, .frontDelts])
        #expect(summary.muscleWeights[.chest] == 10)
    }

    @Test func legsSummary() throws {
        let summary = SessionSummary.make(day: try ppl3Day(2), directory: directory)
        #expect(summary.setCount == 20)
        #expect(summary.estimatedMinutes == 40)
        #expect(summary.topMuscles.first == .glutes)
    }

    @Test func lastRestIsDropped() {
        // 3 séries de 45 s + 2 repos de 60 s = 255 s, soit 4,25 min : 5 minutes.
        let summary = SessionSummary.make(day: day([exercise("bench-press-barbell", sets: 3, rest: 60)]), directory: directory)
        #expect(summary.estimatedMinutes == 5)
    }

    @Test func supersetRoundCountsTwoEffortsAndOneLongerRest() {
        // 4 tours : 4 × (90 + 120) − 120 = 720 s = 12 min → 10 min.
        let pair = [exercise("bench-press-barbell", sets: 4, rest: 60, group: 1),
                    exercise("dips", sets: 4, rest: 120, group: 1, order: 1)]
        let summary = SessionSummary.make(day: day(pair), directory: directory)
        #expect(summary.setCount == 8)
        #expect(summary.estimatedMinutes == 10)
    }

    @Test func unknownUserExercisesCountSetsButNotMuscles() {
        let user = RoutineExercise(order: 0, exercise: .user(id: UUID()), sets: 3, repsMin: 8, repsMax: 10, targetRPE: 9,
                                   restSeconds: 60)
        let summary = SessionSummary.make(day: day([user]), directory: directory)
        #expect(summary.setCount == 3)
        #expect(summary.maxRPE == 9)
        #expect(summary.muscleWeights.isEmpty)
        #expect(summary.topMuscles.isEmpty)
    }

    @Test func customExerciseMusclesCountLikeContentOnes() {
        let shrug = UserExercise(
            name: "Shrug (Haltère)", primaryMuscle: .traps, secondaryMuscles: [.forearms, .traps], equipment: .dumbbell,
            pattern: .shoulderIsolation, region: .upper, isUnilateral: false, defaultIncrementKg: 2.5, defaultRestSeconds: 60,
            createdAt: .t0, updatedAt: .t0)
        let custom = RoutineExercise(order: 1, exercise: .user(id: shrug.id), sets: 4, repsMin: 10, repsMax: 12, targetRPE: 8,
                                     restSeconds: 60)
        let mixed = ExerciseDirectory(library: library, userExercises: [shrug])
        let summary = SessionSummary.make(day: day([exercise("bench-press-barbell", sets: 2, rest: 60), custom]), directory: mixed)
        #expect(summary.setCount == 6)
        #expect(summary.muscleWeights[.traps] == 4)
        #expect(summary.muscleWeights[.forearms] == 2)
        #expect(summary.muscleWeights[.chest] == 2)
        #expect(summary.topMuscles.first == .traps)
    }

    @Test func secondaryMusclesWeighHalf() throws {
        let bench = try #require(library.exercise(id: "bench-press-barbell"))
        let summary = SessionSummary.make(day: day([exercise("bench-press-barbell", sets: 2, rest: 60)]), directory: directory)
        for muscle in bench.primaryMuscles { #expect(summary.muscleWeights[muscle] == 2) }
        for muscle in bench.secondaryMuscles where !bench.primaryMuscles.contains(muscle) {
            #expect(summary.muscleWeights[muscle] == 1)
        }
    }

    @Test func emptyDay() {
        let summary = SessionSummary.make(day: day([]), directory: directory)
        #expect(summary.setCount == 0 && summary.estimatedMinutes == 0 && summary.maxRPE == 0)
    }
}
