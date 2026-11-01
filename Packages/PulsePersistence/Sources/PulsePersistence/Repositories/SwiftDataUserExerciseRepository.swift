import Foundation
import PulseDomain
import SwiftData

@ModelActor
public actor SwiftDataUserExerciseRepository: UserExerciseRepository {
    public func all(includeArchived: Bool) throws -> [UserExercise] {
        let predicate: Predicate<StoredUserExercise> = includeArchived
            ? #Predicate { $0.deletedAt == nil }
            : #Predicate { $0.deletedAt == nil && $0.isArchived == false }
        let descriptor = FetchDescriptor<StoredUserExercise>(predicate: predicate,
                                                             sortBy: [SortDescriptor(\.name), SortDescriptor(\.createdAt)])
        return try modelContext.fetch(descriptor).map { $0.toDomain() }
    }

    public func save(_ exercise: UserExercise) throws {
        var stamped = exercise
        stamped.updatedAt = Date()
        let id = exercise.id
        if let existing = try modelContext.first(StoredUserExercise.self, where: #Predicate { $0.id == id && $0.deletedAt == nil }) {
            existing.apply(stamped)
        } else {
            modelContext.insert(StoredUserExercise(stamped))
        }
        try modelContext.save()
    }

    public func delete(id: UUID) throws {
        guard let stored = try modelContext.first(StoredUserExercise.self, where: #Predicate { $0.id == id && $0.deletedAt == nil }) else {
            return
        }
        stored.deletedAt = Date()
        try modelContext.save()
    }
}
