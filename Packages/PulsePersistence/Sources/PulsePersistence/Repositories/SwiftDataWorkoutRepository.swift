import Foundation
import PulseDomain
import SwiftData

@ModelActor
public actor SwiftDataWorkoutRepository: WorkoutRepository {
    /// Fusionne les séances Pulse (magasin synchronisé) et les séances importées d'Apple Health (magasin local).
    /// Les courses Pulse retrouvent leur FC et leur RPE estimé dans le résumé local.
    public func sessions(from: Date, to: Date) throws -> [WorkoutSession] {
        let rows = try modelContext.fetch(FetchDescriptor<StoredWorkoutSession>(
            predicate: #Predicate { $0.deletedAt == nil && $0.startedAt >= from && $0.startedAt < to }))
        let synced = try RunHealthSummaryJoin.fill(rows.map { $0.toDomain() }, in: modelContext)
        let imported = try modelContext.fetch(FetchDescriptor<StoredImportedWorkout>(
            predicate: #Predicate { $0.deletedAt == nil && $0.startedAt >= from && $0.startedAt < to })).map { $0.toDomain() }
        return (synced + imported).sorted { ($0.startedAt, $0.createdAt) < ($1.startedAt, $1.createdAt) }
    }

    public func session(id: UUID) throws -> WorkoutSession? {
        if let synced = try modelContext.first(StoredWorkoutSession.self, where: #Predicate { $0.id == id && $0.deletedAt == nil }) {
            return try RunHealthSummaryJoin.fill([synced.toDomain()], in: modelContext).first
        }
        return try modelContext.first(StoredImportedWorkout.self, where: #Predicate { $0.id == id && $0.deletedAt == nil })?.toDomain()
    }

    /// Une requête de comptage sur le magasin synchronisé, où vivent toutes les séances Pulse.
    public func completedPulseSessionCount(kind: SessionKind) throws -> Int {
        let completed = SessionStatus.completed.rawValue
        let pulse = SessionSource.pulse.rawValue
        let kindValue = kind.rawValue
        return try modelContext.fetchCount(FetchDescriptor<StoredWorkoutSession>(predicate: #Predicate {
            $0.deletedAt == nil && $0.status == completed && $0.source == pulse && $0.kind == kindValue
        }))
    }

    /// Une seule ligne lue, la plus ancienne du magasin synchronisé : les séances importées d'Apple Health vivent dans le
    /// magasin local et ne comptent pas.
    public func oldestRecordedStart() throws -> Date? {
        let health = SessionSource.appleHealth.rawValue
        var descriptor = FetchDescriptor<StoredWorkoutSession>(
            predicate: #Predicate { $0.deletedAt == nil && $0.source != health }, sortBy: [SortDescriptor(\.startedAt)])
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first?.startedAt
    }

    /// Une séance importée d'Apple Health (`source == .appleHealth`) va dans le magasin local, les autres dans le magasin synchronisé.
    /// Si la même séance existe dans l'autre magasin (changement de source), elle y est supprimée dans le même `save()`.
    /// Une course Pulse écrit sa FC et son RPE estimé dans le résumé local et `nil` dans le magasin synchronisé (frontière M8).
    public func save(_ session: WorkoutSession) throws {
        var stamped = try RunHealthSummaryJoin.store(session, in: modelContext)
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

    /// Une séance Pulse emporte son résumé cardio local, son tracé et ses photos (suppression logique, comme la séance).
    public func delete(id: UUID) throws {
        let now = Date()
        if let stored = try modelContext.first(StoredWorkoutSession.self, where: #Predicate { $0.id == id && $0.deletedAt == nil }) {
            stored.deletedAt = now
            stored.updatedAt = now
            for set in stored.sets ?? [] where set.deletedAt == nil {
                set.deletedAt = now
            }
            try RunHealthSummaryJoin.remove(sessionID: id, in: modelContext)
            try modelContext.markRunTracksDeleted(sessionID: id, at: now)
            try modelContext.markSessionPhotosDeleted(sessionID: id, at: now)
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
    /// dans l'ordre. Une séance qui ne contient que des échauffements de l'exercice est ignorée, une séance faite en décharge
    /// appliquée aussi : ses charges baissées ne sont pas une référence.
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
        // De la plus récente à la plus ancienne : les ajustements ne sont décodés que jusqu'à la première séance hors décharge.
        let sessions = candidates.map(\.session).sorted { Self.isEarlier($1, $0) }
        guard let latest = sessions.first(where: { !Self.isDeloaded($0) }) else { return [] }
        return candidates.filter { $0.session === latest }.map { $0.set.toDomain() }.sorted { $0.order < $1.order }
    }

    /// Les `limit` dernières séances terminées ou abandonnées contenant l'exercice hors échauffement et commencées avant `date`,
    /// de la plus récente à la plus ancienne, décharges comprises. Lit les séries de l'exercice, comme `lastSets`, et la note de
    /// l'exercice sur la colonne des notes de chaque séance retenue.
    public func recentSessions(for exercise: ExerciseReference, startedBefore date: Date, limit: Int) throws
        -> [RecentExerciseSession] {
        let contentID = exercise.contentID
        let userID = exercise.userID
        let inProgress = SessionStatus.inProgress.rawValue
        let warmup = SetType.warmup.rawValue
        let descriptor = FetchDescriptor<StoredWorkoutSet>(predicate: #Predicate {
            $0.deletedAt == nil && $0.setType != warmup && $0.contentExerciseID == contentID && $0.userExerciseID == userID
                && $0.session != nil && $0.session?.deletedAt == nil && $0.session?.status != inProgress
        })
        var setsBySession: [ObjectIdentifier: (session: StoredWorkoutSession, sets: [StoredWorkoutSet])] = [:]
        for stored in try modelContext.fetch(descriptor) {
            guard let session = stored.session, session.startedAt < date else { continue }
            setsBySession[ObjectIdentifier(session), default: (session, [])].sets.append(stored)
        }
        let latest = setsBySession.values.sorted { Self.isEarlier($1.session, $0.session) }.prefix(max(0, limit))
        return latest.map { entry in
            let notes = CodableColumn.decode([ExerciseNote].self, from: entry.session.exerciseNotes, default: [])
            let note = notes.first { $0.exercise == exercise }?.text
            return RecentExerciseSession(startedAt: entry.session.startedAt, isDeloaded: Self.isDeloaded(entry.session),
                                         sets: entry.sets.map { $0.toDomain() }.sorted { $0.order < $1.order },
                                         note: note?.isEmpty == false ? note : nil)
        }
    }

    /// Vrai pour une séance faite en décharge appliquée, lue sur la colonne des ajustements sans charger la séance.
    private static func isDeloaded(_ session: StoredWorkoutSession) -> Bool {
        WorkoutSession.isDeloaded(
            applied: CodableColumn.decode([SessionAdjustment].self, from: session.appliedAdjustments, default: []))
    }

    private static func isEarlier(_ lhs: StoredWorkoutSession, _ rhs: StoredWorkoutSession) -> Bool {
        (lhs.startedAt, lhs.createdAt) < (rhs.startedAt, rhs.createdAt)
    }
}
