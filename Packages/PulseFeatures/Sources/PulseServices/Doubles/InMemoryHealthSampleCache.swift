import Foundation
import PulseDomain

/// Cache d'échantillons en mémoire, même sémantique que `SwiftDataHealthSampleCache`.
public actor InMemoryHealthSampleCache: HealthSampleCache {
    private var stored: [CachedHealthSample] = []
    private var anchors: [HealthSampleKind: Data] = [:]

    public init() {}

    public func samples(kind: HealthSampleKind, from: Date, to: Date) async throws -> [CachedHealthSample] {
        stored.filter { $0.kind == kind && $0.start >= from && $0.start < to }.sorted { $0.start < $1.start }
    }

    public func insert(_ samples: [CachedHealthSample]) async throws {
        stored += samples
    }

    public func apply(_ changes: HealthSampleChanges) async throws {
        let removed = Set(changes.deletedHealthKitUUIDs + changes.added.compactMap(\.healthKitUUID))
        stored.removeAll { sample in
            sample.kind == changes.kind && (changes.isFullRead || sample.healthKitUUID.map(removed.contains) == true)
        }
        stored += changes.added
        anchors[changes.kind] = changes.anchor
    }

    public func anchor(for kind: HealthSampleKind) async throws -> Data? {
        anchors[kind]
    }

    public func saveAnchor(_ data: Data, for kind: HealthSampleKind) async throws {
        anchors[kind] = data
    }

    public func clear() async throws {
        stored = []
        anchors = [:]
    }
}
