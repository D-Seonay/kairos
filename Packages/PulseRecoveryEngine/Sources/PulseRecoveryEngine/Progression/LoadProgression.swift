import Foundation
import PulseDomain

/// Une série proposée pour aujourd'hui : charge et répétitions, ou durée pour un exercice tenu.
public struct ProposedSet: Sendable, Equatable, Codable {
    public var weightKg: Double?
    public var reps: Int?
    public var durationSeconds: Int?
    public var isIncrease: Bool

    public init(weightKg: Double? = nil, reps: Int? = nil, durationSeconds: Int? = nil, isIncrease: Bool = false) {
        self.weightKg = weightKg
        self.reps = reps
        self.durationSeconds = durationSeconds
        self.isIncrease = isIncrease
    }
}

public struct ExerciseProposal: Sendable, Equatable {
    public var sets: [ProposedSet]
    public var loadAdjustment: SessionAdjustment?

    public init(sets: [ProposedSet], loadAdjustment: SessionAdjustment? = nil) {
        self.sets = sets
        self.loadAdjustment = loadAdjustment
    }
}

/// Double progression série par série (spec M4 §8.1) : la série *n* d'aujourd'hui se compare à la série *n* de la dernière fois.
public enum LoadProgression {
    public static let maxRPEForIncrease = 8.0

    // swiftlint:disable function_parameter_count
    /// `lastSets` ne contient ni échauffement ni série hors ordre : la série *n* est la *n*-ième. Pour un exercice tenu, la fourchette
    /// de la routine se lit en secondes.
    public static func propose(exercise: RoutineExercise, name: String, loadKind: LoadKind, tracksDuration: Bool,
                               lastSets: [WorkoutSet], incrementKg: Double, rounding: WeightRounding,
                               policy: ProgressionPolicy) -> ExerciseProposal {
        let context = Context(loadKind: loadKind, tracksDuration: tracksDuration, incrementKg: incrementKg, rounding: rounding,
                              policy: policy)
        var sets: [ProposedSet] = []
        var outcomes: [Outcome] = []
        for index in 0..<max(0, exercise.sets) {
            let (set, outcome) = proposeSet(range: exercise.repRange(forSet: index), reference: lastSets[safe: index] ?? lastSets.last,
                                            context: context)
            sets.append(set)
            outcomes.append(outcome)
        }
        return ExerciseProposal(sets: sets, loadAdjustment: LoadAdjustmentText.adjustment(name: name, outcomes: outcomes, context: context))
    }
    // swiftlint:enable function_parameter_count

    struct Context {
        var loadKind: LoadKind
        var tracksDuration: Bool
        var incrementKg: Double
        var rounding: WeightRounding
        var policy: ProgressionPolicy
    }

    enum Outcome: Equatable {
        case kept
        case increased(deltaKg: Double, reached: Int)
        case assistanceAtZero(reached: Int)
    }

    private static func proposeSet(range: ClosedRange<Int>, reference: WorkoutSet?, context: Context) -> (ProposedSet, Outcome) {
        guard let reference, let reached = reachedValue(reference, tracksDuration: context.tracksDuration) else {
            return (proposed(weightKg: nil, value: range.lowerBound, context: context), .kept)
        }
        let previousWeight = reference.actualWeightKg
        let canIncrease = context.policy.allowsIncrease && reached >= range.upperBound
            && (reference.rpe ?? 0) <= maxRPEForIncrease
        if canIncrease, context.loadKind == .assisted, (previousWeight ?? 0) <= 0 {
            return (proposed(weightKg: 0, value: reached + 1, context: context), .assistanceAtZero(reached: reached))
        }
        if canIncrease, let next = nextWeight(after: previousWeight, context: context) {
            return (proposed(weightKg: next, value: range.lowerBound, isIncrease: true, context: context),
                    .increased(deltaKg: abs(next - (previousWeight ?? 0)), reached: reached))
        }
        let keptWeight = context.loadKind == .assisted ? (previousWeight ?? 0) : previousWeight
        let value = context.policy.allowsIncrease ? min(reached + 1, range.upperBound) : reached
        return (proposed(weightKg: keptWeight, value: value, context: context), .kept)
    }

    /// Charge de la hausse selon la nature ; `nil` quand elle n'existe pas (charge externe jamais saisie).
    private static func nextWeight(after weightKg: Double?, context: Context) -> Double? {
        switch context.loadKind {
        case .external:
            guard let weightKg else { return nil }
            return PlateRounding.nextLoad(after: weightKg, increment: context.incrementKg, rounding: context.rounding)
        case .bodyweight:
            return (weightKg ?? 0) + context.incrementKg
        case .assisted:
            return max(0, (weightKg ?? 0) - context.incrementKg)
        }
    }

    private static func reachedValue(_ set: WorkoutSet, tracksDuration: Bool) -> Int? {
        tracksDuration ? set.durationSeconds : set.actualReps
    }

    private static func proposed(weightKg: Double?, value: Int, isIncrease: Bool = false, context: Context) -> ProposedSet {
        ProposedSet(weightKg: weightKg, reps: context.tracksDuration ? nil : value,
                    durationSeconds: context.tracksDuration ? value : nil, isIncrease: isIncrease)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
