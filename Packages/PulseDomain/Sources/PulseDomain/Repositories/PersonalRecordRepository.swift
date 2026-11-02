import Foundation

public protocol PersonalRecordRepository: Sendable {
    /// Tous les records, ou ceux d'un exercice, triés par date décroissante.
    func records(for exercise: ExerciseReference?) async throws -> [PersonalRecord]
    func save(_ record: PersonalRecord) async throws
    func delete(id: UUID) async throws
    /// Remplace l'ensemble des records par ceux du recalcul. Un record dont la clé (`setID`, `kind`, `weightKg`) existe déjà
    /// garde son enregistrement (même `id`, valeurs mises à jour), les absents sont supprimés, les nouveaux insérés.
    func replaceAll(with records: [PersonalRecord]) async throws
}
