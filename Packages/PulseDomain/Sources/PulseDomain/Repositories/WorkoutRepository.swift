import Foundation

public protocol WorkoutRepository: Sendable {
    /// Séances dont `startedAt` est dans `[from, to)`, triées par date croissante.
    func sessions(from: Date, to: Date) async throws -> [WorkoutSession]
    func session(id: UUID) async throws -> WorkoutSession?
    /// Enregistre la séance et ses séries.
    func save(_ session: WorkoutSession) async throws
    func delete(id: UUID) async throws
    /// Séries hors échauffement (travail, dégressives, échec) de la dernière séance terminée ou abandonnée, non supprimée,
    /// contenant l'exercice, triées par ordre. Une séance en cours n'est pas « la dernière fois ».
    func lastSets(for exercise: ExerciseReference) async throws -> [WorkoutSet]
}
