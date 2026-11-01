import Foundation
import PulseDomain
@testable import PulsePersistence
import Testing

@Test func supplementsAndIntakes() async throws {
    let repo = SwiftDataSupplementRepository(modelContainer: try TestContainer.make())
    let creatine = Sample.supplement(name: "Créatine", order: 1)
    let whey = Sample.supplement(name: "Whey", order: 0)
    let old = Sample.supplement(name: "Ancien", order: 2, archived: true)
    for supplement in [creatine, whey, old] { try await repo.save(supplement) }
    #expect(try await repo.supplements(includeArchived: false).map(\.name) == ["Whey", "Créatine"])
    #expect(try await repo.supplements(includeArchived: true).map(\.name) == ["Whey", "Créatine", "Ancien"])
    let first = Sample.intake(supplementID: creatine.id, takenAt: Fixed.t0)
    let second = Sample.intake(supplementID: creatine.id, takenAt: Fixed.t0.addingTimeInterval(3_600))
    let outside = Sample.intake(supplementID: whey.id, takenAt: Fixed.t0.addingTimeInterval(86_400 * 2))
    for intake in [second, first, outside] { try await repo.save(intake) }
    #expect(try await repo.intakes(from: Fixed.t0, to: Fixed.t0.addingTimeInterval(86_400)).map(\.id) == [first.id, second.id])
    try await repo.delete(intakeID: first.id)
    #expect(try await repo.intakes(from: .distantPast, to: .distantFuture).map(\.id) == [second.id, outside.id])
    try await repo.delete(id: whey.id)
    #expect(try await repo.supplements(includeArchived: true).map(\.name) == ["Créatine", "Ancien"])
}
