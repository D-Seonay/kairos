import Foundation
import PulseDomain
import SwiftData

@ModelActor
public actor SwiftDataBodyMeasurementRepository: BodyMeasurementRepository {
    /// Fusionne les mesures saisies à la main (magasin synchronisé) et celles d'Apple Health (magasin local).
    public func measurements(from: Date, to: Date) throws -> [BodyMeasurement] {
        let synced = try modelContext.fetch(FetchDescriptor<StoredBodyMeasurement>(
            predicate: #Predicate { $0.deletedAt == nil && $0.date >= from && $0.date < to })).map { $0.toDomain() }
        let imported = try modelContext.fetch(FetchDescriptor<StoredImportedBodyMeasurement>(
            predicate: #Predicate { $0.deletedAt == nil && $0.date >= from && $0.date < to })).map { $0.toDomain() }
        return (synced + imported).sorted { ($0.date, $0.createdAt) < ($1.date, $1.createdAt) }
    }

    /// Une mesure d'Apple Health (`source == .appleHealth`) va dans le magasin local, les autres dans le magasin synchronisé.
    /// Si la même mesure existe dans l'autre magasin (changement de source), elle y est supprimée dans le même `save()`.
    public func save(_ measurement: BodyMeasurement) throws {
        var stamped = measurement
        stamped.updatedAt = Date()
        let id = measurement.id
        if measurement.source == .appleHealth {
            if let other = try modelContext.first(StoredBodyMeasurement.self, where: #Predicate { $0.id == id }) {
                modelContext.delete(other)
            }
            let predicate: Predicate<StoredImportedBodyMeasurement> = #Predicate { $0.id == id && $0.deletedAt == nil }
            if let existing = try modelContext.first(StoredImportedBodyMeasurement.self, where: predicate) {
                existing.apply(stamped)
            } else {
                modelContext.insert(StoredImportedBodyMeasurement(stamped))
            }
        } else {
            if let other = try modelContext.first(StoredImportedBodyMeasurement.self, where: #Predicate { $0.id == id }) {
                modelContext.delete(other)
            }
            if let existing = try modelContext.first(StoredBodyMeasurement.self, where: #Predicate { $0.id == id && $0.deletedAt == nil }) {
                existing.apply(stamped)
            } else {
                modelContext.insert(StoredBodyMeasurement(stamped))
            }
        }
        try modelContext.save()
    }

    public func delete(id: UUID) throws {
        if let stored = try modelContext.first(StoredBodyMeasurement.self, where: #Predicate { $0.id == id && $0.deletedAt == nil }) {
            stored.deletedAt = Date()
        } else if let imported = try modelContext.first(StoredImportedBodyMeasurement.self,
                                                        where: #Predicate { $0.id == id && $0.deletedAt == nil }) {
            imported.deletedAt = Date()
        } else {
            return
        }
        try modelContext.save()
    }
}
