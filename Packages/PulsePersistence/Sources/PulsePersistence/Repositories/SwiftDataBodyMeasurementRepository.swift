import Foundation
import PulseDomain
import SwiftData

@ModelActor
public actor SwiftDataBodyMeasurementRepository: BodyMeasurementRepository {
    public func measurements(from: Date, to: Date) throws -> [BodyMeasurement] {
        let descriptor = FetchDescriptor<StoredBodyMeasurement>(
            predicate: #Predicate { $0.deletedAt == nil && $0.date >= from && $0.date < to },
            sortBy: [SortDescriptor(\.date), SortDescriptor(\.createdAt)])
        return try modelContext.fetch(descriptor).map { $0.toDomain() }
    }

    public func save(_ measurement: BodyMeasurement) throws {
        var stamped = measurement
        stamped.updatedAt = Date()
        let id = measurement.id
        if let existing = try modelContext.first(StoredBodyMeasurement.self, where: #Predicate { $0.id == id && $0.deletedAt == nil }) {
            existing.apply(stamped)
        } else {
            modelContext.insert(StoredBodyMeasurement(stamped))
        }
        try modelContext.save()
    }

    public func delete(id: UUID) throws {
        let predicate: Predicate<StoredBodyMeasurement> = #Predicate { $0.id == id && $0.deletedAt == nil }
        guard let stored = try modelContext.first(StoredBodyMeasurement.self, where: predicate) else { return }
        stored.deletedAt = Date()
        try modelContext.save()
    }
}
