import Foundation

public protocol ProgramRepository: Sendable {
    func programs(includeArchived: Bool) async throws -> [Program]
    func program(id: UUID) async throws -> Program?
    /// Enregistre le programme entier ; les jours et exercices absents sont supprimés logiquement.
    func save(_ program: Program) async throws
    func delete(id: UUID) async throws
}
