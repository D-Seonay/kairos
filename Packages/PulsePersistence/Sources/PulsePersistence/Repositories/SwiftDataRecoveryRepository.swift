import Foundation
import PulseDomain
import SwiftData

/// Scores et check-ins : un enregistrement par jour local, remplacé à chaque `save`.
@ModelActor
public actor SwiftDataRecoveryRepository: RecoveryRepository {
    public func dailyRecoveries(from: Date, to: Date) throws -> [DailyRecovery] {
        let descriptor = FetchDescriptor<StoredDailyRecovery>(
            predicate: #Predicate { $0.deletedAt == nil && $0.day >= from && $0.day < to },
            sortBy: [SortDescriptor(\.day)])
        return try modelContext.fetch(descriptor).map { $0.toDomain() }
    }

    public func save(_ recovery: DailyRecovery) throws {
        var stamped = recovery
        stamped.day = Calendar.current.startOfDay(for: recovery.day)
        stamped.updatedAt = Date()
        let day = stamped.day
        if let existing = try modelContext.first(StoredDailyRecovery.self, where: #Predicate { $0.day == day && $0.deletedAt == nil }) {
            stamped.id = existing.id
            stamped.createdAt = existing.createdAt
            existing.apply(stamped)
        } else {
            modelContext.insert(StoredDailyRecovery(stamped))
        }
        try modelContext.save()
    }

    public func checkIns(from: Date, to: Date) throws -> [CheckIn] {
        let descriptor = FetchDescriptor<StoredCheckIn>(
            predicate: #Predicate { $0.deletedAt == nil && $0.day >= from && $0.day < to },
            sortBy: [SortDescriptor(\.day)])
        return try modelContext.fetch(descriptor).map { $0.toDomain() }
    }

    public func save(_ checkIn: CheckIn) throws {
        var stamped = checkIn
        stamped.day = Calendar.current.startOfDay(for: checkIn.day)
        stamped.updatedAt = Date()
        let day = stamped.day
        if let existing = try modelContext.first(StoredCheckIn.self, where: #Predicate { $0.day == day && $0.deletedAt == nil }) {
            stamped.id = existing.id
            stamped.createdAt = existing.createdAt
            existing.apply(stamped)
        } else {
            modelContext.insert(StoredCheckIn(stamped))
        }
        try modelContext.save()
    }
}
