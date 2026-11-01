import Foundation

public protocol PersonalRecordRepository: Sendable {
    /// Tous les records, ou ceux d'un exercice, triés par date décroissante.
    func records(for exercise: ExerciseReference?) async throws -> [PersonalRecord]
    func save(_ record: PersonalRecord) async throws
    func delete(id: UUID) async throws
}
