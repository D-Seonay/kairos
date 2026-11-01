import Foundation
import PulseDomain
import SwiftData

/// Scores et check-ins : un enregistrement par jour local, remplacé à chaque `save`. Le jour est normalisé avec `calendar`.
public actor SwiftDataRecoveryRepository: ModelActor, RecoveryRepository {
    public nonisolated let modelContainer: ModelContainer
    public nonisolated let modelExecutor: any ModelExecutor
    private let calendar: Calendar

    public init(modelContainer: ModelContainer, calendar: Calendar) {
        self.modelContainer = modelContainer
        modelExecutor = DefaultSerialModelExecutor(modelContext: ModelContext(modelContainer))
        self.calendar = calendar
    }

    public func dailyRecoveries(from: Date, to: Date) throws -> [DailyRecovery] {
        let descriptor = FetchDescriptor<StoredDailyRecovery>(
            predicate: #Predicate { $0.deletedAt == nil && $0.day >= from && $0.day < to },
            sortBy: [SortDescriptor(\.day)])
        return try modelContext.fetch(descriptor).map { $0.toDomain() }
    }

    public func save(_ recovery: DailyRecovery) throws {
        var stamped = recovery
        stamped.day = calendar.startOfDay(for: recovery.day)
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
        stamped.day = calendar.startOfDay(for: checkIn.day)
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
