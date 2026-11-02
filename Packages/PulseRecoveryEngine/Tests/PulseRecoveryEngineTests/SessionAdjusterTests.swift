import Foundation
import PulseDomain
@testable import PulseRecoveryEngine
import Testing

struct SessionAdjusterTests {
    private struct PushSpec {
        var id: String
        var sets: Int
        var rest: Int
        var group: Int?
    }

    /// Jour de musculation à la main : l'identité de chaque exercice est stable, pour comparer deux jours avec `==`.
    private func strengthDay(_ specs: [(sets: Int, group: Int?)], rpe: Double = 8, rest: Int = 90) -> RoutineDay {
        let exercises = specs.enumerated().map { index, spec in
            RoutineExercise(id: UUID(uuidString: "00000000-0000-0000-0000-\(String(format: "%012d", index))") ?? UUID(),
                            order: index, exercise: .content(id: "exercise-\(index)"), sets: spec.sets, repsMin: 8, repsMax: 12,
                            targetRPE: rpe, restSeconds: rest, supersetGroup: spec.group)
        }
        return RoutineDay(id: UUID(), order: 0, name: "Test", kind: .strength, exercises: exercises)
    }

    /// Le Push de PPL 3 : 19 séries, un super set (triceps + poignet), tous à RPE `rpe`.
    private func push(rpe: Double = 8) -> RoutineDay {
        let specs = [
            PushSpec(id: "bench-press-barbell", sets: 4, rest: 120, group: nil),
            PushSpec(id: "chest-press-machine", sets: 3, rest: 90, group: nil),
            PushSpec(id: "pec-deck-machine", sets: 3, rest: 60, group: nil),
            PushSpec(id: "triceps-pushdown-cable", sets: 3, rest: 60, group: 1),
            PushSpec(id: "wrist-curl-cable", sets: 3, rest: 60, group: 1),
            PushSpec(id: "crunch-machine", sets: 3, rest: 60, group: nil)
        ]
        let exercises = specs.enumerated().map { index, spec in
            RoutineExercise(id: UUID(uuidString: "11111111-0000-0000-0000-\(String(format: "%012d", index))") ?? UUID(),
                            order: index, exercise: .content(id: spec.id), sets: spec.sets, repsMin: 8, repsMax: 12,
                            targetRPE: rpe, restSeconds: spec.rest, supersetGroup: spec.group)
        }
        return RoutineDay(id: UUID(), order: 0, name: "Push", kind: .strength, exercises: exercises)
    }

    /// Push de 6 exercices à 3 séries (18 séries) : le développé couché a une fourchette par série, les autres non.
    private func pushWithSetTargets() -> RoutineDay {
        let ids = ["bench-press-barbell", "chest-press-machine", "pec-deck-machine", "triceps-pushdown-cable", "wrist-curl-cable",
                   "crunch-machine"]
        let exercises = ids.enumerated().map { index, id in
            RoutineExercise(order: index, exercise: .content(id: id), sets: 3, repsMin: 8, repsMax: 12, targetRPE: 8, restSeconds: 90,
                            setTargets: index == 0 ? [SetTarget(repsMin: 10, repsMax: 12), SetTarget(repsMin: 4, repsMax: 6),
                                                      SetTarget(repsMin: 4, repsMax: 6)] : nil)
        }
        return RoutineDay(id: UUID(), order: 0, name: "Push", kind: .strength, exercises: exercises)
    }

    private func runDay(_ type: RunType) -> RoutineDay {
        RoutineDay(id: UUID(), order: 1, name: "Course", kind: .run, runType: type, runTargetMinutes: 40)
    }

    @Test func optimalChangesNothing() {
        let day = push()
        let adjusted = SessionAdjuster.adjust(day, category: .optimal)
        #expect(adjusted.day == day)
        #expect(adjusted.adjustments.isEmpty)
        #expect(adjusted.removedSets == 0)
        #expect(!adjusted.isVolumeReduced)
        #expect(!adjusted.isReplacedByMobility)
    }

    @Test func normalAddsFifteenSeconds() {
        let day = push()
        let adjusted = SessionAdjuster.adjust(day, category: .normal)
        #expect(adjusted.day.exercises.map(\.restSeconds) == [135, 105, 75, 75, 75, 75])
        #expect(adjusted.day.exercises.map(\.sets) == day.exercises.map(\.sets))
        #expect(adjusted.day.exercises.map(\.id) == day.exercises.map(\.id))
        #expect(adjusted.adjustments == [SessionAdjustment(kind: .rest, reason: "Repos rallongés de 15 secondes", value: 15)])
    }

    @Test func moderateFatigueOnPush() {
        let day = push()
        let adjusted = SessionAdjuster.adjust(day, category: .moderateFatigue)
        #expect(adjusted.day.exercises.map(\.sets) == [3, 2, 2, 3, 3, 2])
        #expect(adjusted.removedSets == 4)
        #expect(adjusted.isVolumeReduced)
        #expect(adjusted.day.exercises.allSatisfy { $0.targetRPE == 7.5 })
        #expect(adjusted.day.exercises.map(\.restSeconds) == [165, 135, 105, 105, 105, 105])
        #expect(adjusted.day.exercises.map(\.id) == day.exercises.map(\.id))
        #expect(adjusted.day.exercises.map(\.order) == day.exercises.map(\.order))
        #expect(adjusted.day.exercises.map(\.exercise) == day.exercises.map(\.exercise))
        #expect(adjusted.adjustments == [
            SessionAdjustment(kind: .volume, reason: "Volume réduit de 19 à 15 séries", value: -4),
            SessionAdjustment(kind: .rpeCap, reason: "Effort plafonné à RPE 7,5", value: 7.5),
            SessionAdjustment(kind: .rest, reason: "Repos rallongés de 45 secondes", value: 45)
        ])
    }

    @Test func fatigueRemovesTheLastPerSetTargets() {
        let adjusted = SessionAdjuster.adjust(pushWithSetTargets(), category: .moderateFatigue)
        let bench = adjusted.day.exercises[0]
        #expect(bench.sets == 2)
        #expect(bench.setTargets == [SetTarget(repsMin: 10, repsMax: 12), SetTarget(repsMin: 4, repsMax: 6)])
        #expect(adjusted.day.exercises.allSatisfy { $0.setTargets == nil || $0.setTargets?.count == $0.sets })
    }

    @Test func supersetLosesSetsTogether() {
        let day = strengthDay([(4, 1), (4, 1), (2, nil)])
        let adjusted = SessionAdjuster.adjust(day, category: .moderateFatigue)
        #expect(adjusted.day.exercises.map(\.sets) == [3, 3, 2])
        #expect(adjusted.removedSets == 2)
    }

    @Test func supersetSkippedWhenOneSetIsLeft() {
        let day = strengthDay([(3, 1), (3, 1), (1, nil)])
        let adjusted = SessionAdjuster.adjust(day, category: .moderateFatigue)
        #expect(adjusted.day.exercises.map(\.sets) == [3, 3, 1])
        #expect(adjusted.removedSets == 0)
        #expect(!adjusted.adjustments.contains { $0.kind == .volume })
    }

    @Test func volumeLoopsOverRounds() {
        let day = strengthDay([(6, nil), (1, nil), (1, nil)])
        let adjusted = SessionAdjuster.adjust(day, category: .moderateFatigue)
        #expect(adjusted.day.exercises.map(\.sets) == [4, 1, 1])
        #expect(adjusted.removedSets == 2)
    }

    @Test func capOnlyWhenItLowersATarget() {
        let adjusted = SessionAdjuster.adjust(push(rpe: 7), category: .moderateFatigue)
        #expect(adjusted.adjustments.map(\.kind) == [.volume, .rest])
        #expect(adjusted.day.exercises.allSatisfy { $0.targetRPE == 7 })
    }

    @Test func overreachedStrengthProposesMobility() {
        let day = push()
        let adjusted = SessionAdjuster.adjust(day, category: .overreached)
        #expect(adjusted.day == day)
        #expect(adjusted.removedSets == 0)
        #expect(adjusted.isReplacedByMobility)
        #expect(adjusted.adjustments == [
            SessionAdjustment(kind: .replaceWithMobility, reason: "Séance remplacée par 20 min de mobilité ou du repos, au choix",
                              value: 20)
        ])
    }

    @Test func runDays() {
        let intervals = runDay(.intervals)
        let swapped = SessionAdjuster.adjust(intervals, category: .moderateFatigue)
        #expect(swapped.adjustments == [
            SessionAdjustment(kind: .swapIntervalsForEasy, reason: "Fractionné remplacé par une sortie facile")
        ])
        #expect(swapped.day == intervals)
        #expect(SessionAdjuster.adjust(runDay(.easy), category: .moderateFatigue).adjustments.isEmpty)

        let tired = runDay(.long)
        let rest = SessionAdjuster.adjust(tired, category: .overreached)
        #expect(rest.adjustments == [SessionAdjustment(kind: .suggestRest, reason: "Repos conseillé plutôt que la course")])
        #expect(rest.day == tired)
        #expect(!rest.isReplacedByMobility)
        #expect(SessionAdjuster.adjust(tired, category: .normal).adjustments.isEmpty)
        #expect(SessionAdjuster.adjust(tired, category: .optimal).adjustments.isEmpty)
    }
}
