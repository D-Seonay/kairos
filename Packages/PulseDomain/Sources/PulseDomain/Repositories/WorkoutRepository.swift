import Foundation

public protocol WorkoutRepository: Sendable {
    /// Séances dont `startedAt` est dans `[from, to)`, triées par date croissante.
    func sessions(from: Date, to: Date) async throws -> [WorkoutSession]
    func session(id: UUID) async throws -> WorkoutSession?
    /// Enregistre la séance et ses séries.
    func save(_ session: WorkoutSession) async throws
    func delete(id: UUID) async throws
    /// Séries hors échauffement (travail, dégressives, échec) de la dernière séance terminée ou abandonnée, non supprimée,
    /// contenant l'exercice et commencée avant `date`, triées par ordre. Une séance en cours n'est pas « la dernière fois ».
    /// Une séance saisie après coup (spec M4 §19.4) lit ainsi l'historique antérieur à son début. Une séance faite en décharge
    /// appliquée (`WorkoutSession.isDeloaded`) n'est jamais « la dernière fois » : les charges proposées repartent de la séance
    /// d'avant la décharge.
    func lastSets(for exercise: ExerciseReference, startedBefore date: Date) async throws -> [WorkoutSet]
    /// Les `limit` dernières séances terminées ou abandonnées, non supprimées, contenant l'exercice hors échauffement et
    /// commencées avant `date`, de la plus récente à la plus ancienne, décharges comprises (marquées) : la pause depuis la
    /// dernière fois, les échecs répétés et la note à reprendre.
    func recentSessions(for exercise: ExerciseReference, startedBefore date: Date, limit: Int) async throws
        -> [RecentExerciseSession]
    /// Le nombre de séances Pulse (`source == .pulse`) de ce genre, terminées et non supprimées : la demande de note.
    func completedPulseSessionCount(kind: SessionKind) async throws -> Int
    /// Le début de la plus ancienne séance non supprimée qui ne vient pas d'Apple Santé, ou `nil` sans aucune : le début de
    /// l'historique d'entraînement, que l'accueil lit à chaque passage.
    func oldestRecordedStart() async throws -> Date?
}

extension WorkoutRepository {
    /// Par défaut, lit toutes les séances ; le magasin SwiftData ne lit que la plus ancienne.
    public func oldestRecordedStart() async throws -> Date? {
        try await sessions(from: .distantPast, to: .distantFuture).lazy.filter { $0.source != .appleHealth }.map(\.startedAt).min()
    }

    /// Par défaut, compte les séances lues ; le magasin SwiftData compte sans les charger.
    public func completedPulseSessionCount(kind: SessionKind) async throws -> Int {
        try await sessions(from: .distantPast, to: .distantFuture)
            .filter { $0.status == .completed && $0.source == .pulse && $0.kind == kind }.count
    }

    /// Par défaut, lit toutes les séances d'avant `date` ; le magasin SwiftData ne lit que les séries de l'exercice.
    public func recentSessions(for exercise: ExerciseReference, startedBefore date: Date, limit: Int) async throws
        -> [RecentExerciseSession] {
        let finished = try await sessions(from: .distantPast, to: date).filter { $0.status != .inProgress }
        let ordered = finished.sorted { ($0.startedAt, $0.createdAt) > ($1.startedAt, $1.createdAt) }
        return Array(ordered.lazy.compactMap { RecentExerciseSession($0, exercise: exercise) }.prefix(max(0, limit)))
    }

    /// Les séries de la dernière fois, quelle que soit sa date.
    public func lastSets(for exercise: ExerciseReference) async throws -> [WorkoutSet] {
        try await lastSets(for: exercise, startedBefore: .distantFuture)
    }
}
