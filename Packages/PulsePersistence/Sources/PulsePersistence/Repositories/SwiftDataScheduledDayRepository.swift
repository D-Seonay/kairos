import Foundation
import PulseDomain
import SwiftData

@ModelActor
public actor SwiftDataScheduledDayRepository: ScheduledDayRepository {
    public func days(from: Date, to: Date) throws -> [ScheduledDay] {
        let descriptor = FetchDescriptor<StoredScheduledDay>(
            predicate: #Predicate { $0.deletedAt == nil && $0.date >= from && $0.date < to },
            sortBy: [SortDescriptor(\.date), SortDescriptor(\.createdAt)])
        return try modelContext.fetch(descriptor).map { $0.toDomain() }
    }

    public func save(_ day: ScheduledDay) throws {
        var stamped = day
        stamped.updatedAt = Date()
        let id = day.id
        if let existing = try modelContext.first(StoredScheduledDay.self, where: #Predicate { $0.id == id && $0.deletedAt == nil }) {
            existing.apply(stamped)
        } else {
            modelContext.insert(StoredScheduledDay(stamped))
        }
        try modelContext.save()
    }

    public func delete(id: UUID) throws {
        guard let stored = try modelContext.first(StoredScheduledDay.self, where: #Predicate { $0.id == id && $0.deletedAt == nil }) else {
            return
        }
        stored.deletedAt = Date()
        try modelContext.save()
    }
}
