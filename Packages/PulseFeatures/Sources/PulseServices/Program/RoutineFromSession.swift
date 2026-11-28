import Foundation
import PulseDomain

/// Fait d'une séance réalisée un jour de routine (spec M4 §12).
public enum RoutineFromSession {
    /// Une séance qui s'écarte de plus de cette marge entre ses séries reçoit une fourchette par série.
    private static let perSetSpread = 3
    /// L'écart visé entre les deux bornes d'une fourchette unique.
    private static let singleRangeWidth = 4
    private static let rampThreshold = 10

    public static func day(from session: WorkoutSession, directory: ExerciseDirectory, order: Int) -> RoutineDay {
        var references: [ExerciseReference] = []
        var setsByReference: [ExerciseReference: [WorkoutSet]] = [:]
        for set in session.sets.sorted(by: { $0.order < $1.order }) where set.setType != .warmup {
            if setsByReference[set.exercise] == nil { references.append(set.exercise) }
            setsByReference[set.exercise, default: []].append(set)
        }
        let exercises = references.enumerated().map { position, reference in
            exercise(at: position, reference: reference, sets: setsByReference[reference] ?? [], directory: directory)
        }
        let day = RoutineDay(order: order, name: session.title, kind: .strength,
                             exercises: pairedSupersets(exercises, sets: setsByReference, references: references))
        return RoutineEditor.normalized(day)
    }

    /// Les séries, répétitions, secondes et le repos sont ramenés dans les bornes de `RoutineRules` : la routine s'enregistre
    /// telle quelle.
    /// Un exercice tenu garde une seule fourchette : des écarts de quelques secondes ne font pas une progression par série.
    private static func exercise(at position: Int, reference: ExerciseReference, sets: [WorkoutSet],
                                 directory: ExerciseDirectory) -> RoutineExercise {
        let info = directory.info(reference)
        let held = info?.tracksDuration ?? false
        let bounds = held ? RoutineRules.seconds : RoutineRules.reps
        let count = min(sets.count, RoutineRules.sets.upperBound)
        let performed = sets.compactMap { held ? $0.durationSeconds : $0.actualReps }.filter { $0 > 0 }
        let values = performed.prefix(count).map { min(max($0, bounds.lowerBound), bounds.upperBound) }
        var exercise = RoutineExercise(
            order: position, exercise: reference, sets: count, repsMin: held ? 30 : 8, repsMax: held ? 60 : 12,
            targetRPE: 8, restSeconds: RoutineRules.routineRest(info?.defaultRestSeconds ?? RoutineEditor.fallbackRestSeconds))
        guard let low = values.min(), let high = values.max() else { return exercise }
        if !held, high - low > perSetSpread, performed.count == sets.count {
            exercise.setTargets = values.map(perSetRange)
            exercise.repsMin = exercise.setTargets?.map(\.repsMin).min() ?? low
            exercise.repsMax = exercise.setTargets?.map(\.repsMax).max() ?? high
        } else {
            exercise.repsMin = max(bounds.lowerBound, min(low, high - singleRangeWidth))
            exercise.repsMax = high
        }
        return exercise
    }

    private static func perSetRange(_ reps: Int) -> SetTarget {
        reps >= rampThreshold
            ? SetTarget(repsMin: max(1, reps - 2), repsMax: reps)
            : SetTarget(repsMin: max(1, reps - 1), repsMax: reps + 1)
    }

    /// Reprend les super sets de la séance : les exercices consécutifs qui partagent un groupe, de deux à
    /// `RoutineEditor.maxSupersetSize`, forment un groupe. Un groupe plus long est coupé en morceaux de cette taille.
    private static func pairedSupersets(_ exercises: [RoutineExercise], sets: [ExerciseReference: [WorkoutSet]],
                                        references: [ExerciseReference]) -> [RoutineExercise] {
        let groups = references.map { sets[$0]?.compactMap(\.supersetGroup).first }
        var result = exercises
        var start = 0
        var next = 1
        while start < result.count {
            var end = start + 1
            while end < result.count, end - start < RoutineEditor.maxSupersetSize, groups[start] != nil,
                  groups[end] == groups[start] { end += 1 }
            if end - start >= 2 {
                for position in start..<end { result[position].supersetGroup = next }
                next += 1
            }
            start = end
        }
        return result
    }
}
