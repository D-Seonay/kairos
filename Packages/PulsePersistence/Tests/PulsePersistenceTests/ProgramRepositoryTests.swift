import Foundation
import PulseDomain
@testable import PulsePersistence
import SwiftData
import Testing

@Test func programSaveReadsBackSortedAndDeleteHides() async throws {
    let repo = SwiftDataProgramRepository(modelContainer: try TestContainer.make())
    let program = Sample.program()
    let before = Date()
    try await repo.save(program)
    let loaded = try #require(try await repo.program(id: program.id))
    #expect(loaded.days == program.days && loaded.weekLayout == program.weekLayout && loaded.templateID == "ppl-3")
    #expect(loaded.updatedAt >= before && loaded.createdAt == program.createdAt)
    try await repo.delete(id: program.id)
    #expect(try await repo.program(id: program.id) == nil)
    #expect(try await repo.programs(includeArchived: true).isEmpty)
}

@Test func programSaveRemovingADayDeletesItLogically() async throws {
    let repo = SwiftDataProgramRepository(modelContainer: try TestContainer.make())
    var program = Sample.program(days: 2)
    try await repo.save(program)
    program.days.removeLast()
    try await repo.save(program)
    #expect(try await repo.program(id: program.id)?.days.count == 1)
    let context = ModelContext(repo.modelContainer)
    let days = try context.fetch(FetchDescriptor<StoredRoutineDay>())
    #expect(days.count == 2 && days.filter { $0.deletedAt != nil }.count == 1)
}

@Test func programsOrderedByCreatedAtThenNameAndArchivedFilter() async throws {
    let repo = SwiftDataProgramRepository(modelContainer: try TestContainer.make())
    var second = Sample.program()
    second.name = "B"
    second.createdAt = Fixed.t2
    var first = Sample.program()
    first.name = "A"
    first.createdAt = Fixed.t1
    var archived = Sample.program()
    archived.name = "Z"
    archived.createdAt = Fixed.t0
    archived.isArchived = true
    for program in [second, first, archived] { try await repo.save(program) }
    #expect(try await repo.programs(includeArchived: false).map(\.name) == ["A", "B"])
    #expect(try await repo.programs(includeArchived: true).map(\.name) == ["Z", "A", "B"])
}
