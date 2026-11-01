import Foundation
import PulseDomain
@testable import PulsePersistence
import SwiftData
import Testing

@Test func activeSessionStoreSingleSlot() async throws {
    let store = SwiftDataActiveSessionStore(modelContainer: try TestContainer.make())
    #expect(try await store.load() == nil)
    try await store.save(Sample.snapshot())
    let second = ActiveSessionSnapshot(startedAt: Fixed.t1, updatedAt: Fixed.t2, payload: Data([9]))
    try await store.save(second)
    #expect(try await store.load() == second)
    let context = ModelContext(store.modelContainer)
    #expect(try context.fetchCount(FetchDescriptor<StoredActiveSessionSnapshot>()) == 1)
    try await store.clear()
    #expect(try await store.load() == nil)
}
