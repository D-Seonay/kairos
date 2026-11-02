import Foundation
import PulseDomain
import SwiftData

/// Cache local des échantillons Apple Santé : suppression physique, jamais logique.
@ModelActor
public actor SwiftDataHealthSampleCache: HealthSampleCache {
    public func samples(kind: HealthSampleKind, from: Date, to: Date) throws -> [CachedHealthSample] {
        let raw = kind.rawValue
        let descriptor = FetchDescriptor<StoredCachedHealthSample>(
            predicate: #Predicate { $0.kind == raw && $0.start >= from && $0.start < to },
            sortBy: [SortDescriptor(\.start)])
        return try modelContext.fetch(descriptor).map { $0.toDomain() }
    }

    public func replace(kind: HealthSampleKind, with samples: [CachedHealthSample]) throws {
        let raw = kind.rawValue
        try modelContext.delete(model: StoredCachedHealthSample.self, where: #Predicate { $0.kind == raw })
        for sample in samples {
            modelContext.insert(StoredCachedHealthSample(sample))
        }
        try modelContext.save()
    }

    public func insert(_ samples: [CachedHealthSample]) throws {
        for sample in samples {
            modelContext.insert(StoredCachedHealthSample(sample))
        }
        try modelContext.save()
    }

    public func apply(_ changes: HealthSampleChanges) throws {
        let raw = changes.kind.rawValue
        if changes.isFullRead {
            try modelContext.delete(model: StoredCachedHealthSample.self, where: #Predicate { $0.kind == raw })
        } else {
            let removed = Set(changes.deletedHealthKitUUIDs + changes.added.compactMap(\.healthKitUUID))
            let existing = try modelContext.fetch(FetchDescriptor<StoredCachedHealthSample>(predicate: #Predicate { $0.kind == raw }))
            for stored in existing where stored.healthKitUUID.map(removed.contains) == true {
                modelContext.delete(stored)
            }
        }
        for sample in changes.added {
            modelContext.insert(StoredCachedHealthSample(sample))
        }
        try upsertAnchor(changes.anchor, for: changes.kind)
        try modelContext.save()
    }

    public func anchor(for kind: HealthSampleKind) throws -> Data? {
        let raw = kind.rawValue
        return try modelContext.first(StoredHealthQueryAnchor.self, where: #Predicate { $0.kind == raw })?.anchorData
    }

    public func saveAnchor(_ data: Data, for kind: HealthSampleKind) throws {
        try upsertAnchor(data, for: kind)
        try modelContext.save()
    }

    private func upsertAnchor(_ data: Data, for kind: HealthSampleKind) throws {
        let raw = kind.rawValue
        if let existing = try modelContext.first(StoredHealthQueryAnchor.self, where: #Predicate { $0.kind == raw }) {
            existing.anchorData = data
            existing.updatedAt = Date()
        } else {
            modelContext.insert(StoredHealthQueryAnchor(kind: kind, anchorData: data))
        }
    }

    public func clear() throws {
        try modelContext.delete(model: StoredCachedHealthSample.self)
        try modelContext.delete(model: StoredHealthQueryAnchor.self)
        try modelContext.save()
    }
}
