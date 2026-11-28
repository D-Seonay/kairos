import Foundation
import PulseDomain

/// Le dépôt que voient l'Accueil, le planning, les stats et l'historique : il masque les courses de la montre déjà couvertes par
/// une course Pulse (`RunDuplicates`). `WorkoutHistory` garde le dépôt brut, il doit voir les séances importées pour les aligner.
public struct DeduplicatingWorkoutRepository: WorkoutRepository {
    private static let margin: TimeInterval = 24 * 3_600

    private let base: any WorkoutRepository

    public init(base: any WorkoutRepository) {
        self.base = base
    }

    /// Lit un jour de plus de chaque côté pour que le doublon d'une course proche d'un bord soit vu, résout, puis recoupe.
    public func sessions(from: Date, to: Date) async throws -> [WorkoutSession] {
        let wide = try await base.sessions(from: from.addingTimeInterval(-Self.margin), to: to.addingTimeInterval(Self.margin))
        return RunDuplicates.resolve(wide).filter { $0.startedAt >= from && $0.startedAt < to }
    }

    /// Les doublons masqués sont des séances de la montre : le compte des séances Pulse est celui du dépôt brut.
    public func completedPulseSessionCount(kind: SessionKind) async throws -> Int {
        try await base.completedPulseSessionCount(kind: kind)
    }

    /// Les doublons masqués viennent d'Apple Santé : ils ne font jamais le début de l'historique, lu au dépôt brut.
    public func oldestRecordedStart() async throws -> Date? {
        try await base.oldestRecordedStart()
    }

    /// Une course Pulse se lit avec la FC et le RPE estimé de son doublon, comme dans les listes.
    public func session(id: UUID) async throws -> WorkoutSession? {
        guard let session = try await base.session(id: id), RunDuplicates.isPulseRun(session) else {
            return try await base.session(id: id)
        }
        let window = try await base.sessions(from: session.startedAt.addingTimeInterval(-Self.margin),
                                             to: RunDuplicates.end(of: session).addingTimeInterval(Self.margin))
        return RunDuplicates.resolve(window).first { $0.id == id } ?? session
    }

    /// Une course Pulse déjà enregistrée garde en magasin sa FC et son RPE estimé : ce que la lecture a emprunté à un doublon de la
    /// montre n'y entre jamais (les valeurs lues d'Apple Santé restent locales, spec M8). Une course neuve garde la FC du direct.
    public func save(_ session: WorkoutSession) async throws {
        guard RunDuplicates.isPulseRun(session), let stored = try await base.session(id: session.id) else {
            return try await base.save(session)
        }
        var kept = session
        kept.averageHeartRate = stored.averageHeartRate
        kept.estimatedRPE = stored.estimatedRPE
        try await base.save(kept)
    }

    public func delete(id: UUID) async throws {
        try await base.delete(id: id)
    }

    public func lastSets(for exercise: ExerciseReference, startedBefore date: Date) async throws -> [WorkoutSet] {
        try await base.lastSets(for: exercise, startedBefore: date)
    }

    public func recentSessions(for exercise: ExerciseReference, startedBefore date: Date, limit: Int) async throws
        -> [RecentExerciseSession] {
        try await base.recentSessions(for: exercise, startedBefore: date, limit: limit)
    }
}
