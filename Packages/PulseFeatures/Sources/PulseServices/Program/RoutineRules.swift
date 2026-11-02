import Foundation
import PulseDomain

/// Ce qui ne va pas dans les paramètres d'un exercice de routine.
public enum RoutineIssue: Sendable, Equatable {
    case sets
    case reps
    case rpe
    case rest
    /// Le nombre de fourchettes par série diffère de `sets`, ou l'une d'elles est inversée.
    case setTargets
}

/// Les bornes que l'éditeur de routine impose aux paramètres d'un exercice (spec M4 §12).
public enum RoutineRules {
    public static let sets = 1...10
    public static let reps = 1...30
    /// Les bornes d'un exercice tenu, en secondes.
    public static let seconds = 5...600
    public static let rpe = 6.0...10.0
    public static let rpeStep = 0.5
    public static let rest = 0...300
    public static let restStep = 15

    /// Les problèmes de `exercise`, dans l'ordre séries, répétitions, RPE, repos, fourchettes par série.
    /// Une fourchette inversée est signalée sans jamais passer par `repRange(forSet:)`, qui planterait.
    public static func issues(in exercise: RoutineExercise, tracksDuration: Bool) -> [RoutineIssue] {
        var issues: [RoutineIssue] = []
        if !sets.contains(exercise.sets) { issues.append(.sets) }
        let bounds = tracksDuration ? seconds : reps
        if exercise.repsMin > exercise.repsMax || !bounds.contains(exercise.repsMin) || !bounds.contains(exercise.repsMax) {
            issues.append(.reps)
        }
        if !rpe.contains(exercise.targetRPE) || !isMultiple(exercise.targetRPE, of: rpeStep) { issues.append(.rpe) }
        if !rest.contains(exercise.restSeconds) || !exercise.restSeconds.isMultiple(of: restStep) { issues.append(.rest) }
        if let targets = exercise.setTargets, targets.count != exercise.sets || targets.contains(where: { $0.repsMin > $0.repsMax }) {
            issues.append(.setTargets)
        }
        return issues
    }

    private static func isMultiple(_ value: Double, of step: Double) -> Bool {
        let steps = value / step
        return abs(steps - steps.rounded()) < 1e-9
    }
}
