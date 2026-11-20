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
    /// Une séance saisie après coup (spec M4 §19.4) lit ainsi l'historique antérieur à son début.
    func lastSets(for exercise: ExerciseReference, startedBefore date: Date) async throws -> [WorkoutSet]
}

extension WorkoutRepository {
    /// Les séries de la dernière fois, quelle que soit sa date.
    public func lastSets(for exercise: ExerciseReference) async throws -> [WorkoutSet] {
        try await lastSets(for: exercise, startedBefore: .distantFuture)
    }
}
