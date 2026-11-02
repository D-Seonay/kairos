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

    /// Séries hors échauffement de la dernière séance terminée ou abandonnée contenant l'exercice, dans l'ordre.
    /// Lit les séries de l'exercice (et non chaque séance) : seules les séries à retenir deviennent des valeurs du domaine.
    public func lastSets(for exercise: ExerciseReference) throws -> [WorkoutSet] {
        let contentID = exercise.contentID
        let userID = exercise.userID
        let inProgress = SessionStatus.inProgress.rawValue
        let descriptor = FetchDescriptor<StoredWorkoutSet>(predicate: #Predicate {
            $0.deletedAt == nil && $0.contentExerciseID == contentID && $0.userExerciseID == userID
                && $0.session != nil && $0.session?.deletedAt == nil && $0.session?.status != inProgress
        })
        let candidates = try modelContext.fetch(descriptor).compactMap { stored in
            stored.session.map { (session: $0, set: stored) }
        }
        guard let latest = candidates.map(\.session).max(by: Self.isEarlier) else { return [] }
        return candidates.filter { $0.session === latest }.map { $0.set.toDomain() }
            .filter { $0.setType != .warmup }.sorted { $0.order < $1.order }
    }

    private static func isEarlier(_ lhs: StoredWorkoutSession, _ rhs: StoredWorkoutSession) -> Bool {
        (lhs.startedAt, lhs.createdAt) < (rhs.startedAt, rhs.createdAt)
    }
}
