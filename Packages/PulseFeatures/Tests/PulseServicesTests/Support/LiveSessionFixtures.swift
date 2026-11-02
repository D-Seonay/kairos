import Foundation
import PulseDomain
import PulseServices

/// Les exercices, l'historique et les jours de récupération partagés par les suites de la séance en direct.
enum LiveFixtures {
    static let directory = ExerciseDirectory(library: .bundled, userExercises: [])
    static let bench = ExerciseReference.content(id: "bench-press-barbell")
    static let pecDeck = ExerciseReference.content(id: "pec-deck-machine")
    static let plank = ExerciseReference.content(id: "plank")
    static let pullUp = ExerciseReference.content(id: "pull-up")
    static let assistedPullUp = ExerciseReference.content(id: "assisted-pull-up-machine")

    static func exercise(_ reference: ExerciseReference, order: Int = 0, sets: Int = 3, reps: ClosedRange<Int> = 8...12,
                         rpe: Double = 8, rest: Int = 90, superset: Int? = nil) -> RoutineExercise {
        RoutineExercise(order: order, exercise: reference, sets: sets, repsMin: reps.lowerBound, repsMax: reps.upperBound,
                        targetRPE: rpe, restSeconds: rest, supersetGroup: superset)
    }

    static func day(_ exercises: [RoutineExercise], name: String = "Push") -> RoutineDay {
        RoutineDay(order: 0, name: name, kind: .strength, exercises: exercises)
    }

    static func done(_ reference: ExerciseReference, _ weightKg: Double?, _ reps: Int?, seconds: Int? = nil,
                     order: Int = 0) -> WorkoutSet {
        WorkoutSet(order: order, exercise: reference, exerciseName: "x", setType: .working, actualWeightKg: weightKg,
                   actualReps: reps, durationSeconds: seconds)
    }

    /// Bench 60 × 12, 70 × 5, 70 × 5.
    static let rampingBench = [done(bench, 60, 12), done(bench, 70, 5), done(bench, 70, 5)]

    static func recovery(_ category: RecoveryCategory, estimated: Bool = false) -> DailyRecovery {
        let score: Double = switch category {
        case .optimal: 95
        case .normal: 75
        case .moderateFatigue: 50
        case .overreached: 30
        }
        return DailyRecovery(day: .t0, score: score, category: category, isEstimated: estimated, calibration: .ready,
                             createdAt: .t0, updatedAt: .t0)
    }

    static func launch(_ day: RoutineDay, _ category: RecoveryCategory?, originalChosen: Bool = false) -> SessionLaunch {
        SessionLaunch.routine(day, programID: nil, recovery: category.map { recovery($0) }, originalChosen: originalChosen,
                              profile: UserProfile(createdAt: .t0, updatedAt: .t0))
    }

    static func session(_ launch: SessionLaunch, history: [ExerciseReference: [WorkoutSet]] = [:]) -> LiveSession {
        LiveSessionPlanner.session(for: launch, directory: directory, history: history, settings: [:],
                                   profile: UserProfile(createdAt: .t0, updatedAt: .t0), now: .t0)
    }
}
