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
    /// Le nombre de séances Pulse (`source == .pulse`) de ce genre, terminées et non supprimées : la demande de note.
    func completedPulseSessionCount(kind: SessionKind) async throws -> Int
}

extension WorkoutRepository {
    /// Par défaut, compte les séances lues ; le magasin SwiftData compte sans les charger.
    public func completedPulseSessionCount(kind: SessionKind) async throws -> Int {
        try await sessions(from: .distantPast, to: .distantFuture)
            .filter { $0.status == .completed && $0.source == .pulse && $0.kind == kind }.count
    }

    /// Les séries de la dernière fois, quelle que soit sa date.
    public func lastSets(for exercise: ExerciseReference) async throws -> [WorkoutSet] {
        try await lastSets(for: exercise, startedBefore: .distantFuture)
    }
}
