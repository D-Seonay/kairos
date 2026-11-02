import Foundation
import PulseDomain
import PulseServices

/// Un dépôt de programmes en mémoire dont les lectures lèvent sur commande.
actor FailingProgramRepository: ProgramRepository {
    enum Failure: Error { case unreadable }

    private let inner = InMemoryProgramRepository()
    private var fails = false

    func setFails(_ value: Bool) {
        fails = value
    }

    func programs(includeArchived: Bool) async throws -> [Program] {
        try check()
        return try await inner.programs(includeArchived: includeArchived)
    }

    func program(id: UUID) async throws -> Program? {
        try check()
        return try await inner.program(id: id)
    }

    func save(_ program: Program) async throws {
        try await inner.save(program)
    }

    func delete(id: UUID) async throws {
        try await inner.delete(id: id)
    }

    private func check() throws {
        if fails { throw Failure.unreadable }
    }
}
