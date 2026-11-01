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
