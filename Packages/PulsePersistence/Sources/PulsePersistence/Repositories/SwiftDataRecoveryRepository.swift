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
        let recoveries = try modelContext.fetch(descriptor).map { $0.toDomain() }
        let readings = try modelContext.fetch(FetchDescriptor<StoredRecoveryReading>(
            predicate: #Predicate { $0.day >= from && $0.day < to }, sortBy: [SortDescriptor(\.day)]))
        return RecoveryReadingJoin.fill(recoveries, with: readings)
    }

    /// Le score va dans le magasin synchronisé, les valeurs brutes d'Apple Health dans le magasin local, en un seul `save()`.
    /// Une ancienne ligne synchronisée perd ses valeurs brutes : celles de `recovery` font foi et partent dans la lecture locale.
    public func save(_ recovery: DailyRecovery) throws {
        var stamped = recovery
        stamped.day = calendar.startOfDay(for: recovery.day)
        stamped.updatedAt = Date()
        let day = stamped.day
        if let existing = try modelContext.first(StoredDailyRecovery.self, where: #Predicate { $0.day == day && $0.deletedAt == nil }) {
            stamped.id = existing.id
            stamped.createdAt = existing.createdAt
            existing.apply(stamped)
            existing.clearHealthValues()
        } else {
            modelContext.insert(StoredDailyRecovery(stamped))
        }
        try writeReading(of: stamped, day: day)
        try modelContext.save()
    }

    /// Crée, met à jour ou supprime la lecture locale du jour, selon qu'il reste des valeurs brutes.
    private func writeReading(of recovery: DailyRecovery, day: Date) throws {
        let now = recovery.updatedAt
        let existing = try modelContext.first(StoredRecoveryReading.self, where: #Predicate { $0.day == day })
        if let existing {
            existing.apply(recovery, at: now)
            if existing.isEmpty { modelContext.delete(existing) }
        } else {
            let reading = StoredRecoveryReading(day: day, from: recovery, at: now)
            if !reading.isEmpty { modelContext.insert(reading) }
        }
    }

    /// Ne touche que les lectures locales : la ligne synchronisée (et son `updatedAt`) reste telle quelle. Une seule lecture
    /// SwiftData pour toute la plage des nuits à phases (les lectures déjà à phases restent en base), puis un seul `save()`.
    public func backfillSleepStages(_ nights: [NightSample]) throws {
        var sleepByDay: [Date: SleepSummary] = [:]
        for night in nights {
            guard let sleep = night.sleep, sleep.coreMinutes != nil else { continue }
            sleepByDay[calendar.startOfDay(for: night.day)] = sleep
        }
        guard let first = sleepByDay.keys.min(), let last = sleepByDay.keys.max(),
              let end = calendar.date(byAdding: .day, value: 1, to: last) else { return }
        let readings = try modelContext.fetch(FetchDescriptor<StoredRecoveryReading>(
            predicate: #Predicate { $0.day >= first && $0.day < end && $0.coreMinutes == nil }))
        var changed = false
        for reading in readings {
            guard let sleep = sleepByDay[reading.day], reading.asleepMinutes == sleep.asleepMinutes,
                  reading.deepMinutes == sleep.deepMinutes else { continue }
            reading.coreMinutes = sleep.coreMinutes
            reading.remMinutes = sleep.remMinutes
            reading.unspecifiedMinutes = sleep.unspecifiedMinutes
            reading.awakeMinutes = sleep.awakeMinutes
            changed = true
        }
        if changed { try modelContext.save() }
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
