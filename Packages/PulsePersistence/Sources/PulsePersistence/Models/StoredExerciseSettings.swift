import Foundation
import PulseDomain
import SwiftData

@Model
public final class StoredExerciseSettings {
    public var id: UUID = UUID()
    public var contentExerciseID: String?
    public var userExerciseID: UUID?
    public var incrementKg: Double?
    public var warmupSetCount: Int?
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()
    public var deletedAt: Date?

    public init(_ settings: ExerciseSettings) {
        id = settings.id
        createdAt = settings.createdAt
        apply(settings)
    }

    public func apply(_ settings: ExerciseSettings) {
        contentExerciseID = settings.exercise.contentID
        userExerciseID = settings.exercise.userID
        incrementKg = settings.incrementKg
        warmupSetCount = settings.warmupSetCount
        updatedAt = settings.updatedAt
    }

    public func toDomain() -> ExerciseSettings {
        ExerciseSettings(id: id, exercise: ExerciseReference(contentID: contentExerciseID, userID: userExerciseID) ?? .content(id: ""),
                         incrementKg: incrementKg, warmupSetCount: warmupSetCount, createdAt: createdAt, updatedAt: updatedAt)
    }
}
