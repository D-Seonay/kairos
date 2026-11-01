import Foundation
import PulseDomain
import SwiftData

@ModelActor
public actor SwiftDataWorkoutRepository: WorkoutRepository {
    public func sessions(from: Date, to: Date) throws -> [WorkoutSession] {
        let descriptor = FetchDescriptor<StoredWorkoutSession>(
            predicate: #Predicate { $0.deletedAt == nil && $0.startedAt >= from && $0.startedAt < to },
            sortBy: [SortDescriptor(\.startedAt), SortDescriptor(\.createdAt)])
        return try modelContext.fetch(descriptor).map { $0.toDomain() }
    }

    public func session(id: UUID) throws -> WorkoutSession? {
        try modelContext.first(StoredWorkoutSession.self, where: #Predicate { $0.id == id && $0.deletedAt == nil })?.toDomain()
    }

    public func save(_ session: WorkoutSession) throws {
        var stamped = session
        stamped.updatedAt = Date()
        let id = session.id
        if let existing = try modelContext.first(StoredWorkoutSession.self, where: #Predicate { $0.id == id && $0.deletedAt == nil }) {
            existing.apply(stamped)
        } else {
            modelContext.insert(StoredWorkoutSession(stamped))
        }
        try modelContext.save()
    }

    public func delete(id: UUID) throws {
        let predicate: Predicate<StoredWorkoutSession> = #Predicate { $0.id == id && $0.deletedAt == nil }
        guard let stored = try modelContext.first(StoredWorkoutSession.self, where: predicate) else { return }
        let now = Date()
        stored.deletedAt = now
        stored.updatedAt = now
        for set in stored.sets ?? [] where set.deletedAt == nil {
            set.deletedAt = now
        }
        try modelContext.save()
    }

    /// Séries de travail de la dernière séance terminée contenant l'exercice, dans l'ordre.
    public func lastSets(for exercise: ExerciseReference) throws -> [WorkoutSet] {
        let completed = SessionStatus.completed.rawValue
        let descriptor = FetchDescriptor<StoredWorkoutSession>(
            predicate: #Predicate { $0.deletedAt == nil && $0.status == completed },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)])
        for stored in try modelContext.fetch(descriptor) {
            let sets = stored.toDomain().sets.filter { $0.exercise == exercise }
            if !sets.isEmpty {
                return sets.filter { $0.setType == .working }
            }
        }
        return []
    }
}
