import Foundation

/// Le champ d'une série auquel le clavier est lié : l'exercice, la série et la valeur saisie.
public struct KeypadField: Sendable, Equatable {
    public enum Kind: Sendable, Equatable {
        case weight
        case reps
        case duration
    }

    public var exercise: UUID
    public var set: UUID
    public var kind: Kind

    public init(exercise: UUID, set: UUID, kind: Kind) {
        self.exercise = exercise
        self.set = set
        self.kind = kind
    }
}
