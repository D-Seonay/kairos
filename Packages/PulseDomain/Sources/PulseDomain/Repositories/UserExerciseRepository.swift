import Foundation

public protocol UserExerciseRepository: Sendable {
    func all(includeArchived: Bool) async throws -> [UserExercise]
    func save(_ exercise: UserExercise) async throws
    func delete(id: UUID) async throws
}
