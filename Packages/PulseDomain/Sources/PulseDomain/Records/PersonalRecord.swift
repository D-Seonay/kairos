import Foundation

public enum RecordKind: String, Sendable, Codable, CaseIterable {
    case maxWeight
    case estimatedOneRepMax
    case repsAtWeight
}

/// Un record personnel sur un exercice (spec V1 §5.6, §5.8).
public struct PersonalRecord: Sendable, Equatable, Codable, Identifiable {
    public var id: UUID
    public var exercise: ExerciseReference
    public var exerciseName: String
    public var kind: RecordKind
    public var value: Double
    public var weightKg: Double?
    public var date: Date
    public var sessionID: UUID?
    public var setID: UUID?
    public var createdAt: Date
    public var updatedAt: Date

    public init(id: UUID = UUID(), exercise: ExerciseReference, exerciseName: String, kind: RecordKind, value: Double,
                weightKg: Double? = nil, date: Date, sessionID: UUID? = nil, setID: UUID? = nil, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.exercise = exercise
        self.exerciseName = exerciseName
        self.kind = kind
        self.value = value
        self.weightKg = weightKg
        self.date = date
        self.sessionID = sessionID
        self.setID = setID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
