import Foundation

public protocol ExerciseSettingsRepository: Sendable {
    func all() async throws -> [ExerciseSettings]
    /// Les réglages d'un exercice ; le plus récent par `updatedAt` s'il y en a plusieurs (restauration iCloud).
    func settings(for exercise: ExerciseReference) async throws -> ExerciseSettings?
    /// Remplace l'enregistrement actif du même exercice : il est mis à jour et garde son `id`.
    func save(_ settings: ExerciseSettings) async throws
}
