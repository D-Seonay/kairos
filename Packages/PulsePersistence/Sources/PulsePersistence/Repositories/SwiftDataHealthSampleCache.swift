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

    public func insert(_ samples: [CachedHealthSample]) throws {
        for sample in samples {
            modelContext.insert(StoredCachedHealthSample(sample))
        }
        try modelContext.save()
    }

    public func apply(_ changes: HealthSampleChanges) throws {
        do {
            try stage(changes)
            try modelContext.save()
        } catch {
            // Un enregistrement raté ne doit pas laisser ses suppressions et insertions en attente pour l'écriture suivante.
            modelContext.rollback()
            throw error
        }
    }

    private func stage(_ changes: HealthSampleChanges) throws {
        let raw = changes.kind.rawValue
        if changes.isFullRead {
            try modelContext.delete(model: StoredCachedHealthSample.self, where: #Predicate { $0.kind == raw })
        } else {
            // Seuls les échantillons nommés sont lus, pas tout le type.
            // Un tableau d'optionnels, que SwiftData traduit en `IN` ; `nil` n'y figure jamais.
            let removed: [String?] = Set(changes.deletedHealthKitUUIDs + changes.added.compactMap(\.healthKitUUID)).map { $0 }
            let named = FetchDescriptor<StoredCachedHealthSample>(
                predicate: #Predicate { $0.kind == raw && removed.contains($0.healthKitUUID) })
            for stored in try modelContext.fetch(named) {
                modelContext.delete(stored)
            }
        }
        let cutoff = try retentionCutoff(kind: changes.kind, added: changes.added, afterFullRead: changes.isFullRead)
        for sample in changes.added where cutoff.map({ sample.start >= $0 }) ?? true {
            modelContext.insert(StoredCachedHealthSample(sample))
        }
        if let cutoff, !changes.isFullRead {
            let old = FetchDescriptor<StoredCachedHealthSample>(predicate: #Predicate { $0.kind == raw && $0.start < cutoff })
            for stored in try modelContext.fetch(old) {
                modelContext.delete(stored)
            }
        }
        try upsertAnchor(changes.anchor, for: changes.kind)
    }

    /// La date avant laquelle un échantillon du type est élagué : `healthCacheRetention` avant le plus récent, gardé ou ajouté.
    /// `nil` quand le type est vide.
    private func retentionCutoff(kind: HealthSampleKind, added: [CachedHealthSample], afterFullRead: Bool) throws -> Date? {
        let raw = kind.rawValue
        var latest = FetchDescriptor<StoredCachedHealthSample>(predicate: #Predicate { $0.kind == raw },
                                                               sortBy: [SortDescriptor(\.start, order: .reverse)])
        latest.fetchLimit = 1
        let stored = afterFullRead ? nil : try modelContext.fetch(latest).first?.start
        let newest = ([stored] + added.map(\.start)).compactMap { $0 }.max()
        return newest?.addingTimeInterval(-healthCacheRetention)
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
