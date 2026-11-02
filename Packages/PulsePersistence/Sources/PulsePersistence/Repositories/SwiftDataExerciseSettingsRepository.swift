import Foundation
import PulseDomain
import SwiftData

@ModelActor
public actor SwiftDataExerciseSettingsRepository: ExerciseSettingsRepository {
    public func all() throws -> [ExerciseSettings] {
        try modelContext.fetch(FetchDescriptor<StoredExerciseSettings>(predicate: #Predicate { $0.deletedAt == nil },
                                                                       sortBy: [SortDescriptor(\.createdAt)])).map { $0.toDomain() }
    }

    public func settings(for exercise: ExerciseReference) throws -> ExerciseSettings? {
        try matching(exercise).first?.toDomain()
    }

    public func save(_ settings: ExerciseSettings) throws {
        var stamped = settings
        stamped.updatedAt = Date()
        if let existing = try matching(settings.exercise).first {
            stamped.id = existing.id
            stamped.createdAt = existing.createdAt
            existing.apply(stamped)
        } else {
            modelContext.insert(StoredExerciseSettings(stamped))
        }
        try modelContext.save()
    }

    /// Enregistrements actifs de l'exercice, le plus récemment modifié d'abord.
    private func matching(_ exercise: ExerciseReference) throws -> [StoredExerciseSettings] {
        let contentID = exercise.contentID
        let userID = exercise.userID
        let predicate: Predicate<StoredExerciseSettings> = #Predicate {
            $0.deletedAt == nil && $0.contentExerciseID == contentID && $0.userExerciseID == userID
        }
        return try modelContext.fetch(FetchDescriptor<StoredExerciseSettings>(predicate: predicate,
                                                                              sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]))
    }
}
