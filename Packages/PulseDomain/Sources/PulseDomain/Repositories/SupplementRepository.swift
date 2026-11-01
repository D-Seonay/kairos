import Foundation

public protocol SupplementRepository: Sendable {
    func supplements(includeArchived: Bool) async throws -> [Supplement]
    func save(_ supplement: Supplement) async throws
    func delete(id: UUID) async throws
    func intakes(from: Date, to: Date) async throws -> [SupplementIntake]
    func save(_ intake: SupplementIntake) async throws
    func delete(intakeID: UUID) async throws
}
