import Foundation

public enum SetType: String, Sendable, Codable, CaseIterable {
    case warmup
    case working
    case drop
    case failure
}

public enum ReplacementReason: String, Sendable, Codable, CaseIterable {
    case machineBusy
    case pain
    case other
}

/// Une série d'une séance (spec M2 §5.3). Une série « ratée » se lit dans `isMissed`, sans champ dédié.
public struct WorkoutSet: Sendable, Equatable, Codable, Identifiable {
    public var id: UUID
    public var order: Int
    public var exercise: ExerciseReference
    public var exerciseName: String
    public var setType: SetType
    public var supersetGroup: Int?
    public var plannedWeightKg: Double?
    public var plannedReps: Int?
    public var actualWeightKg: Double?
    public var actualReps: Int?
    public var rpe: Double?
    public var restSeconds: Int?
    public var completedAt: Date?
    public var isPersonalRecord: Bool
    public var replacedExercise: ExerciseReference?
    public var replacementReason: ReplacementReason?

    public init(id: UUID = UUID(), order: Int, exercise: ExerciseReference, exerciseName: String, setType: SetType,
                supersetGroup: Int? = nil, plannedWeightKg: Double? = nil, plannedReps: Int? = nil,
                actualWeightKg: Double? = nil, actualReps: Int? = nil, rpe: Double? = nil, restSeconds: Int? = nil,
                completedAt: Date? = nil, isPersonalRecord: Bool = false, replacedExercise: ExerciseReference? = nil,
                replacementReason: ReplacementReason? = nil) {
        self.id = id
        self.order = order
        self.exercise = exercise
        self.exerciseName = exerciseName
        self.setType = setType
        self.supersetGroup = supersetGroup
        self.plannedWeightKg = plannedWeightKg
        self.plannedReps = plannedReps
        self.actualWeightKg = actualWeightKg
        self.actualReps = actualReps
        self.rpe = rpe
        self.restSeconds = restSeconds
        self.completedAt = completedAt
        self.isPersonalRecord = isPersonalRecord
        self.replacedExercise = replacedExercise
        self.replacementReason = replacementReason
    }

    /// Vrai quand moins de répétitions ont été faites que prévu.
    public var isMissed: Bool {
        guard let plannedReps, let actualReps else { return false }
        return actualReps < plannedReps
    }
}
