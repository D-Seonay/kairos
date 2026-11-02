import Foundation
import PulseContent
import PulseDomain
import PulseRecoveryEngine

/// Recalcule les records personnels depuis tout l'historique (spec M4 §8.2) : après un import, une suppression ou une séance
/// corrigée. Ses recalculs passent l'un après l'autre par la même file, pour qu'aucun n'écrive les records d'un historique
/// qu'un autre est en train de relire.
public final class RecordsService: Sendable {
    private let workouts: any WorkoutRepository
    private let records: any PersonalRecordRepository
    private let userExercises: any UserExerciseRepository
    private let library: ContentLibrary
    private let now: @Sendable () -> Date
    private let queue = SerialTaskQueue()

    public init(workouts: any WorkoutRepository, records: any PersonalRecordRepository, userExercises: any UserExerciseRepository,
                library: ContentLibrary, now: @escaping @Sendable () -> Date) {
        self.workouts = workouts
        self.records = records
        self.userExercises = userExercises
        self.library = library
        self.now = now
    }

    /// Remplace les records par ceux de l'historique, puis réenregistre les seules séances terminées ou abandonnées dont une série
    /// gagne ou perd sa marque de record. Rend le nombre de records.
    public func recomputeAll() async throws -> Int {
        try await queue.run { try await self.recompute() }
    }

    private func recompute() async throws -> Int {
        let sessions = try await workouts.sessions(from: .distantPast, to: .distantFuture)
        let directory = ExerciseDirectory(library: library, userExercises: try await userExercises.all(includeArchived: true))
        let now = now()
        let result = RecordBook.compute(sessions: sessions, loadKind: directory.loadKind(of:), now: now)
        try await records.replaceAll(with: result.records)
        for session in sessions where session.status == .completed || session.status == .abandoned {
            guard Self.marked(session, with: result.recordSetIDs) != session else { continue }
            // Les marques sont posées sur une copie relue à l'instant : une modification faite pendant le calcul n'est pas écrasée.
            guard let fresh = try await workouts.session(id: session.id) else { continue }
            var marked = Self.marked(fresh, with: result.recordSetIDs)
            guard marked != fresh else { continue }
            marked.updatedAt = now
            try await workouts.save(marked)
        }
        return result.records.count
    }

    private static func marked(_ session: WorkoutSession, with recordSetIDs: Set<UUID>) -> WorkoutSession {
        var marked = session
        for index in marked.sets.indices {
            marked.sets[index].isPersonalRecord = recordSetIDs.contains(marked.sets[index].id)
        }
        return marked
    }
}
