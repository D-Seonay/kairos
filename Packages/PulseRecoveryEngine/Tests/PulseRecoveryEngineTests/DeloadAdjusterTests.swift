import Foundation
import PulseDomain
import PulseRecoveryEngine
import Testing

struct DeloadAdjusterTests {
    private func day(sets: [Int], groups: [Int?]? = nil, kind: RoutineDayKind = .strength) -> RoutineDay {
        let exercises = sets.enumerated().map { index, count in
            RoutineExercise(order: index, exercise: .content(id: "exercise-\(index)"), sets: count, repsMin: 8, repsMax: 12,
                            targetRPE: 8, restSeconds: 90, supersetGroup: groups?[index])
        }
        return RoutineDay(order: 0, name: "Legs", kind: kind, exercises: exercises)
    }

    @Test func removesFortyPercentOfTheSets() {
        let adjusted = DeloadAdjuster.apply(day(sets: [4, 4, 3, 3, 3, 3]))
        #expect(adjusted.removedSets == 8, "40 % de 20 séries")
        #expect(adjusted.day.exercises.map(\.sets).reduce(0, +) == 12)
        #expect(adjusted.day.exercises.allSatisfy { $0.sets >= 1 })
        #expect(adjusted.adjustments.map(\.kind) == [.deload])
    }

    @Test func keepsTheOrderAndIdentityOfExercises() {
        let original = day(sets: [5, 3, 3], groups: [nil, 1, 1])
        let adjusted = DeloadAdjuster.apply(original)
        #expect(adjusted.day.exercises.map(\.id) == original.exercises.map(\.id))
        #expect(adjusted.day.exercises[1].sets == adjusted.day.exercises[2].sets, "Un super set perd ses séries ensemble")
    }

    @Test func leavesARunDayUntouched() {
        let run = RoutineDay(order: 0, name: "Endurance", kind: .run, runType: .easy, runTargetMinutes: 45)
        #expect(DeloadAdjuster.apply(run) == AdjustedSession(day: run))
    }
}
