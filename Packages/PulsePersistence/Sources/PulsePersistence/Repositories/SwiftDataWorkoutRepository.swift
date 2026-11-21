import Foundation
import PulseDomain
import SwiftData

@ModelActor
public actor SwiftDataWorkoutRepository: WorkoutRepository {
    /// Fusionne les séances Pulse (magasin synchronisé) et les séances importées d'Apple Health (magasin local).
    public func sessions(from: Date, to: Date) throws -> [WorkoutSession] {
        let synced = try modelContext.fetch(FetchDescriptor<StoredWorkoutSession>(
            predicate: #Predicate { $0.deletedAt == nil && $0.startedAt >= from && $0.startedAt < to })).map { $0.toDomain() }
        let imported = try modelContext.fetch(FetchDescriptor<StoredImportedWorkout>(
            predicate: #Predicate { $0.deletedAt == nil && $0.startedAt >= from && $0.startedAt < to })).map { $0.toDomain() }
        return (synced + imported).sorted { ($0.startedAt, $0.createdAt) < ($1.startedAt, $1.createdAt) }
    }

    public func session(id: UUID) throws -> WorkoutSession? {
        if let synced = try modelContext.first(StoredWorkoutSession.self, where: #Predicate { $0.id == id && $0.deletedAt == nil }) {
            return synced.toDomain()
        }
        return try modelContext.first(StoredImportedWorkout.self, where: #Predicate { $0.id == id && $0.deletedAt == nil })?.toDomain()
    }

    /// Une séance importée d'Apple Health (`source == .appleHealth`) va dans le magasin local, les autres dans le magasin synchronisé.
    /// Si la même séance existe dans l'autre magasin (changement de source), elle y est supprimée dans le même `save()`.
    public func save(_ session: WorkoutSession) throws {
        var stamped = session
        stamped.updatedAt = Date()
        let id = session.id
        if session.source == .appleHealth {
            if let other = try modelContext.first(StoredWorkoutSession.self, where: #Predicate { $0.id == id }) {
                modelContext.delete(other)
            }
            if let existing = try modelContext.first(StoredImportedWorkout.self, where: #Predicate { $0.id == id && $0.deletedAt == nil }) {
                existing.apply(stamped)
            } else {
                modelContext.insert(StoredImportedWorkout(stamped))
            }
        } else {
            if let other = try modelContext.first(StoredImportedWorkout.self, where: #Predicate { $0.id == id }) {
                modelContext.delete(other)
            }
            if let existing = try modelContext.first(StoredWorkoutSession.self, where: #Predicate { $0.id == id && $0.deletedAt == nil }) {
                existing.apply(stamped)
            } else {
                modelContext.insert(StoredWorkoutSession(stamped))
            }
        }
        try modelContext.save()
    }

    public func delete(id: UUID) throws {
        let now = Date()
        if let stored = try modelContext.first(StoredWorkoutSession.self, where: #Predicate { $0.id == id && $0.deletedAt == nil }) {
            stored.deletedAt = now
            stored.updatedAt = now
            for set in stored.sets ?? [] where set.deletedAt == nil {
                set.deletedAt = now
            }
        } else if let imported = try modelContext.first(StoredImportedWorkout.self,
                                                        where: #Predicate { $0.id == id && $0.deletedAt == nil }) {
            imported.deletedAt = now
            imported.updatedAt = now
        } else {
            return
        }
        try modelContext.save()
    }

    /// Séries hors échauffement de la dernière séance terminée ou abandonnée contenant l'exercice et commencée avant `date`,
    /// dans l'ordre. Une séance qui ne contient que des échauffements de l'exercice est ignorée.
    /// Lit les séries de l'exercice (et non chaque séance) : seules les séries à retenir deviennent des valeurs du domaine.
    public func lastSets(for exercise: ExerciseReference, startedBefore date: Date) throws -> [WorkoutSet] {
        let contentID = exercise.contentID
        let userID = exercise.userID
        let inProgress = SessionStatus.inProgress.rawValue
        let warmup = SetType.warmup.rawValue
        let descriptor = FetchDescriptor<StoredWorkoutSet>(predicate: #Predicate {
            $0.deletedAt == nil && $0.setType != warmup && $0.contentExerciseID == contentID && $0.userExerciseID == userID
                && $0.session != nil && $0.session?.deletedAt == nil && $0.session?.status != inProgress
        })
        // La date reste hors du prédicat, qui la comparerait à une relation optionnelle : les séries sont déjà celles d'un exercice.
        let candidates = try modelContext.fetch(descriptor).compactMap { stored in
            stored.session.flatMap { $0.startedAt < date ? (session: $0, set: stored) : nil }
        }
        guard let latest = candidates.map(\.session).max(by: Self.isEarlier) else { return [] }
        return candidates.filter { $0.session === latest }.map { $0.set.toDomain() }.sorted { $0.order < $1.order }
    }

    private static func isEarlier(_ lhs: StoredWorkoutSession, _ rhs: StoredWorkoutSession) -> Bool {
        (lhs.startedAt, lhs.createdAt) < (rhs.startedAt, rhs.createdAt)
    }
}
