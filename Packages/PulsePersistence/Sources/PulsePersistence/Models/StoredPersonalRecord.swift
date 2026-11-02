import Foundation
import PulseDomain
import SwiftData

@Model
public final class StoredPersonalRecord {
    public var id: UUID = UUID()
    public var contentExerciseID: String?
    public var userExerciseID: UUID?
    public var exerciseName: String = ""
    public var kind: String = RecordKind.maxWeight.rawValue
    public var value: Double = 0
    public var weightKg: Double?
    public var date: Date = Date()
    public var sessionID: UUID?
    public var setID: UUID?
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()
    public var deletedAt: Date?

    public init(_ record: PersonalRecord) {
        id = record.id
        createdAt = record.createdAt
        apply(record)
    }

    public func apply(_ record: PersonalRecord) {
        contentExerciseID = record.exercise.contentID
        userExerciseID = record.exercise.userID
        exerciseName = record.exerciseName
        kind = record.kind.rawValue
        value = record.value
        weightKg = record.weightKg
        date = record.date
        sessionID = record.sessionID
        setID = record.setID
        updatedAt = record.updatedAt
    }

    /// Vrai si le record n'apporte aucune valeur nouvelle : `updatedAt` n'entre pas en compte.
    func holds(_ record: PersonalRecord) -> Bool {
        var comparable = record
        comparable.id = id
        comparable.createdAt = createdAt
        comparable.updatedAt = updatedAt
        return comparable == toDomain()
    }

    public func toDomain() -> PersonalRecord {
        PersonalRecord(id: id, exercise: ExerciseReference(contentID: contentExerciseID, userID: userExerciseID) ?? .content(id: ""),
                       exerciseName: exerciseName, kind: .stored(kind, default: .maxWeight), value: value, weightKg: weightKg, date: date,
                       sessionID: sessionID, setID: setID, createdAt: createdAt, updatedAt: updatedAt)
    }
}
