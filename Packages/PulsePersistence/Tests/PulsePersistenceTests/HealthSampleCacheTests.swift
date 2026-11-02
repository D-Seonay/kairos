import Foundation
import PulseDomain
@testable import PulsePersistence
import Testing

@Test func cacheReplaceInsertQueryClear() async throws {
    let cache = SwiftDataHealthSampleCache(modelContainer: try TestContainer.make())
    let s1 = Sample.cachedSample(start: Fixed.t0)
    let s2 = Sample.cachedSample(start: Fixed.t0.addingTimeInterval(60))
    let s3 = Sample.cachedSample(start: Fixed.t0.addingTimeInterval(120))
    let sleep = Sample.cachedSample(kind: .sleep, start: Fixed.t0)
    try await cache.replace(kind: .sdnn, with: [s1, s2])
    try await cache.insert([sleep])
    try await cache.replace(kind: .sdnn, with: [s3])
    #expect(try await cache.samples(kind: .sdnn, from: .distantPast, to: .distantFuture).map(\.id) == [s3.id])
    #expect(try await cache.samples(kind: .sleep, from: .distantPast, to: .distantFuture).map(\.id) == [sleep.id])
    #expect(try await cache.samples(kind: .sleep, from: Fixed.t1, to: .distantFuture).isEmpty)
    try await cache.saveAnchor(Data([1, 2]), for: .sleep)
    #expect(try await cache.anchor(for: .sleep) == Data([1, 2]))
    try await cache.saveAnchor(Data([3]), for: .sleep)
    #expect(try await cache.anchor(for: .sleep) == Data([3]))
    #expect(try await cache.anchor(for: .sdnn) == nil)
    try await cache.clear()
    #expect(try await cache.anchor(for: .sleep) == nil)
    #expect(try await cache.samples(kind: .sdnn, from: .distantPast, to: .distantFuture).isEmpty)
}

/// Reconstruire le cache Apple Santé ne doit jamais toucher à la séance en cours (spec M2 §5.4).
@Test func cacheClearKeepsTheActiveSession() async throws {
    let container = try TestContainer.make()
    let store = SwiftDataActiveSessionStore(modelContainer: container)
    try await store.save(Sample.snapshot())
    try await SwiftDataHealthSampleCache(modelContainer: container).clear()
    #expect(try await store.load() != nil)
}

private func anchored(_ kind: HealthSampleKind = .sdnn, uuid: String?, at offset: TimeInterval = 0) -> CachedHealthSample {
    var sample = Sample.cachedSample(kind: kind, start: Fixed.t0.addingTimeInterval(offset))
    sample.healthKitUUID = uuid
    return sample
}

private func all(_ cache: SwiftDataHealthSampleCache, _ kind: HealthSampleKind) async throws -> [CachedHealthSample] {
    try await cache.samples(kind: kind, from: .distantPast, to: .distantFuture)
}

@Test func fullReadReplacesTheKind() async throws {
    let cache = SwiftDataHealthSampleCache(modelContainer: try TestContainer.make())
    let sleep = anchored(.sleep, uuid: "S")
    try await cache.insert([anchored(uuid: nil), anchored(uuid: nil, at: 60), sleep])
    let added = anchored(uuid: "A", at: 120)
    try await cache.apply(HealthSampleChanges(kind: .sdnn, added: [added], deletedHealthKitUUIDs: [],
                                              anchor: Data([7]), isFullRead: true))
    #expect(try await all(cache, .sdnn) == [added])
    #expect(try await all(cache, .sleep) == [sleep])
    #expect(try await cache.anchor(for: .sdnn) == Data([7]))
}

@Test func incrementalReadRemovesDeleted() async throws {
    let cache = SwiftDataHealthSampleCache(modelContainer: try TestContainer.make())
    let first = anchored(uuid: "A")
    let second = anchored(uuid: "B", at: 60)
    try await cache.insert([first, second])
    try await cache.apply(HealthSampleChanges(kind: .sdnn, added: [], deletedHealthKitUUIDs: ["A"],
                                              anchor: Data([1]), isFullRead: false))
    #expect(try await all(cache, .sdnn) == [second])
}

@Test func returningSampleIsNotDuplicated() async throws {
    let cache = SwiftDataHealthSampleCache(modelContainer: try TestContainer.make())
    let sample = anchored(uuid: "A")
    try await cache.insert([sample])
    try await cache.apply(HealthSampleChanges(kind: .sdnn, added: [sample], deletedHealthKitUUIDs: [],
                                              anchor: Data([1]), isFullRead: false))
    #expect(try await all(cache, .sdnn) == [sample])
}

@Test func anchorIsKeptPerKind() async throws {
    let cache = SwiftDataHealthSampleCache(modelContainer: try TestContainer.make())
    try await cache.apply(HealthSampleChanges(kind: .sdnn, added: [anchored(uuid: "A")], deletedHealthKitUUIDs: [],
                                              anchor: Data([1]), isFullRead: false))
    #expect(try await cache.anchor(for: .sleep) == nil)
    #expect(try await cache.anchor(for: .sdnn) == Data([1]))
}
