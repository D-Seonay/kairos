import Foundation
import PulseContent
import PulseDomain

/// Le résumé d'un jour de musculation : séries de travail, durée estimée, intensité maximale et muscles sollicités.
public struct SessionSummary: Sendable, Equatable {
    public var setCount: Int
    public var estimatedMinutes: Int
    public var maxRPE: Double
    public var topMuscles: [Muscle]
    public var muscleWeights: [Muscle: Double]

    public init(setCount: Int, estimatedMinutes: Int, maxRPE: Double, topMuscles: [Muscle], muscleWeights: [Muscle: Double]) {
        self.setCount = setCount
        self.estimatedMinutes = estimatedMinutes
        self.maxRPE = maxRPE
        self.topMuscles = topMuscles
        self.muscleWeights = muscleWeights
    }

    private static let effortSeconds = 45
    private static let topMuscleCount = 3

    public static func make(day: RoutineDay, library: ContentLibrary) -> SessionSummary {
        let exercises = day.exercises.sorted { $0.order < $1.order }
        let weights = muscleWeights(of: exercises, library: library)
        return SessionSummary(
            setCount: exercises.reduce(0) { $0 + $1.sets },
            estimatedMinutes: estimatedMinutes(of: exercises),
            maxRPE: exercises.map(\.targetRPE).max() ?? 0,
            topMuscles: topMuscles(of: weights),
            muscleWeights: weights
        )
    }

    /// 1 par série pour un muscle principal, 0,5 pour un secondaire ; les exercices de l'utilisateur sont ignorés.
    private static func muscleWeights(of exercises: [RoutineExercise], library: ContentLibrary) -> [Muscle: Double] {
        var weights: [Muscle: Double] = [:]
        for routineExercise in exercises {
            guard let id = routineExercise.exercise.contentID, let exercise = library.exercise(id: id) else { continue }
            let sets = Double(routineExercise.sets)
            for muscle in exercise.primaryMuscles { weights[muscle, default: 0] += sets }
            for muscle in exercise.secondaryMuscles where !exercise.primaryMuscles.contains(muscle) {
                weights[muscle, default: 0] += sets / 2
            }
        }
        return weights
    }

    /// Les trois muscles les plus sollicités ; à poids égal, l'ordre de `Muscle.allCases`.
    private static func topMuscles(of weights: [Muscle: Double]) -> [Muscle] {
        let order = Dictionary(uniqueKeysWithValues: Muscle.allCases.enumerated().map { ($1, $0) })
        let ranked = weights.keys.sorted { lhs, rhs in
            let (left, right) = (weights[lhs] ?? 0, weights[rhs] ?? 0)
            return left == right ? (order[lhs] ?? 0) < (order[rhs] ?? 0) : left > right
        }
        return Array(ranked.prefix(topMuscleCount))
    }

    /// 45 s d'effort par série ; un repos après chaque série sauf la dernière de la séance. Un super set compte par tour :
    /// 2 × 45 s d'effort et un seul repos, le plus long des deux. Arrondi aux 5 minutes les plus proches.
    private static func estimatedMinutes(of exercises: [RoutineExercise]) -> Int {
        var rounds: [(effort: Int, rest: Int)] = []
        var handledGroups: Set<Int> = []
        for exercise in exercises {
            guard let group = exercise.supersetGroup else {
                rounds += Array(repeating: (effortSeconds, exercise.restSeconds), count: exercise.sets)
                continue
            }
            guard handledGroups.insert(group).inserted else { continue }
            let members = exercises.filter { $0.supersetGroup == group }
            for round in 0..<(members.map(\.sets).max() ?? 0) {
                let active = members.filter { $0.sets > round }
                rounds.append((effortSeconds * active.count, active.map(\.restSeconds).max() ?? 0))
            }
        }
        guard !rounds.isEmpty else { return 0 }
        let seconds = rounds.reduce(0) { $0 + $1.effort + $1.rest } - (rounds.last?.rest ?? 0)
        return Int((Double(seconds) / 300).rounded()) * 5
    }
}
