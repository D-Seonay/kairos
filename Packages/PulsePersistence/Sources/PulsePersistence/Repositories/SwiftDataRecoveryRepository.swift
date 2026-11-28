import Foundation
import PulseDomain
import SwiftData

/// Scores et check-ins : un enregistrement par jour civil (« 2026-11-27 »), remplacé à chaque `save`. Le jour se lit dans
/// `calendar` ; une ligne écrite dans un autre fuseau (voyage, autre appareil) se retrouve par sa clé et se relit à minuit de
/// `calendar`. Des doublons d'un même jour (deux appareils hors ligne) se relisent comme une seule ligne, la plus récente, et
/// le prochain `save` du jour marque les autres supprimées.
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
        let wide = DayKey.widened(from: from, to: to)
        let (lower, upper) = (wide.from, wide.to)
        let rows = try modelContext.fetch(FetchDescriptor<StoredDailyRecovery>(
            predicate: #Predicate { $0.deletedAt == nil && $0.day >= lower && $0.day < upper }))
        let recoveries = latest(rows, from: from, to: to) { row, day in
            var recovery = row.toDomain()
            recovery.day = day
            return recovery
        }
        let readings = try modelContext.fetch(FetchDescriptor<StoredRecoveryReading>(
            predicate: #Predicate { $0.day >= lower && $0.day < upper }))
        return RecoveryReadingJoin.fill(recoveries, with: readings, calendar: calendar)
    }

    /// Le score va dans le magasin synchronisé, les valeurs brutes d'Apple Health dans le magasin local, en un seul `save()`.
    /// Une ancienne ligne synchronisée perd ses valeurs brutes : celles de `recovery` font foi et partent dans la lecture locale.
    public func save(_ recovery: DailyRecovery) throws {
        let (key, day) = normalized(recovery.day)
        var stamped = recovery
        stamped.day = day
        stamped.updatedAt = Date()
        let rows = try sameDay(StoredDailyRecovery.self, key: key, day: day) { lower, upper in
            #Predicate { $0.deletedAt == nil && $0.day >= lower && $0.day < upper }
        }
        if let existing = rows.first {
            stamped.id = existing.id
            stamped.createdAt = existing.createdAt
            existing.apply(stamped)
            existing.dayKey = key
            existing.clearHealthValues()
            markDeleted(rows.dropFirst(), at: stamped.updatedAt)
        } else {
            let row = StoredDailyRecovery(stamped)
            row.dayKey = key
            modelContext.insert(row)
        }
        try writeReading(of: stamped, key: key)
        try modelContext.save()
    }

    /// Crée, met à jour ou supprime la lecture locale du jour, selon qu'il reste des valeurs brutes ; supprime les lectures en
    /// double du même jour.
    private func writeReading(of recovery: DailyRecovery, key: String) throws {
        let now = recovery.updatedAt
        let rows = try sameDay(StoredRecoveryReading.self, key: key, day: recovery.day) { lower, upper in
            #Predicate { $0.day >= lower && $0.day < upper }
        }
        for duplicate in rows.dropFirst() {
            modelContext.delete(duplicate)
        }
        if let existing = rows.first {
            existing.apply(recovery, at: now)
            existing.dayKey = key
            if existing.isEmpty { modelContext.delete(existing) }
        } else {
            let reading = StoredRecoveryReading(day: recovery.day, dayKey: key, from: recovery, at: now)
            if !reading.isEmpty { modelContext.insert(reading) }
        }
    }

    /// Ne touche que les lectures locales : la ligne synchronisée (et son `updatedAt`) reste telle quelle. Une seule lecture
    /// SwiftData pour toute la plage des nuits à phases (les lectures déjà à phases restent en base), puis un seul `save()`.
    public func backfillSleepStages(_ nights: [NightSample]) throws {
        var sleepByDay: [String: SleepSummary] = [:]
        var days: [Date] = []
        for night in nights {
            guard let sleep = night.sleep, sleep.coreMinutes != nil else { continue }
            sleepByDay[DayKey.key(for: night.day, calendar: calendar)] = sleep
            days.append(night.day)
        }
        guard let first = days.min(), let last = days.max(),
              let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: last)) else { return }
        let wide = DayKey.widened(from: calendar.startOfDay(for: first), to: end)
        let (lower, upper) = (wide.from, wide.to)
        let readings = try modelContext.fetch(FetchDescriptor<StoredRecoveryReading>(
            predicate: #Predicate { $0.day >= lower && $0.day < upper && $0.coreMinutes == nil }))
        var changed = false
        for reading in readings {
            guard let sleep = sleepByDay[DayKey.effective(reading.dayKey, day: reading.day, calendar: calendar)],
                  reading.asleepMinutes == sleep.asleepMinutes, reading.deepMinutes == sleep.deepMinutes else { continue }
            reading.coreMinutes = sleep.coreMinutes
            reading.remMinutes = sleep.remMinutes
            reading.unspecifiedMinutes = sleep.unspecifiedMinutes
            reading.awakeMinutes = sleep.awakeMinutes
            changed = true
        }
        if changed { try modelContext.save() }
    }

    public func checkIns(from: Date, to: Date) throws -> [CheckIn] {
        let wide = DayKey.widened(from: from, to: to)
        let (lower, upper) = (wide.from, wide.to)
        let rows = try modelContext.fetch(FetchDescriptor<StoredCheckIn>(
            predicate: #Predicate { $0.deletedAt == nil && $0.day >= lower && $0.day < upper }))
        return latest(rows, from: from, to: to) { row, day in
            var checkIn = row.toDomain()
            checkIn.day = day
            return checkIn
        }.map(\.recovery)
    }

    public func save(_ checkIn: CheckIn) throws {
        let (key, day) = normalized(checkIn.day)
        var stamped = checkIn
        stamped.day = day
        stamped.updatedAt = Date()
        let rows = try sameDay(StoredCheckIn.self, key: key, day: day) { lower, upper in
            #Predicate { $0.deletedAt == nil && $0.day >= lower && $0.day < upper }
        }
        if let existing = rows.first {
            stamped.id = existing.id
            stamped.createdAt = existing.createdAt
            existing.apply(stamped)
            existing.dayKey = key
            markDeleted(rows.dropFirst(), at: stamped.updatedAt)
        } else {
            let row = StoredCheckIn(stamped)
            row.dayKey = key
            modelContext.insert(row)
        }
        try modelContext.save()
    }

    // MARK: Jours civils

    /// La clé civile de `date` et minuit de ce jour dans `calendar`.
    private func normalized(_ date: Date) -> (key: String, day: Date) {
        let key = DayKey.key(for: date, calendar: calendar)
        return (key, DayKey.date(for: key, calendar: calendar) ?? calendar.startOfDay(for: date))
    }

    /// Les lignes du jour civil `key`, la plus récente d'abord, lues dans une fenêtre assez large pour tous les fuseaux.
    private func sameDay<Row: PersistentModel & DayKeyedRow>(
        _ type: Row.Type, key: String, day: Date, predicate: (Date, Date) -> Predicate<Row>
    ) throws -> [Row] {
        let wide = DayKey.widened(from: day, to: day)
        let rows = try modelContext.fetch(FetchDescriptor<Row>(predicate: predicate(wide.from, wide.to)))
        return DayRows.byDay(rows, calendar: calendar)[key] ?? []
    }

    /// La ligne la plus récente de chaque jour civil dont minuit, dans `calendar`, tombe dans `[from, to)`, triées par jour (une
    /// clé « 2026-11-27 » se trie comme sa date).
    private func latest<Row: DayKeyedRow, Value>(
        _ rows: [Row], from: Date, to: Date, _ transform: (Row, Date) -> Value
    ) -> [(key: String, recovery: Value)] {
        DayRows.byDay(rows, calendar: calendar).compactMap { key, group -> (key: String, recovery: Value)? in
            guard let row = group.first, let day = DayKey.date(for: key, calendar: calendar), day >= from, day < to else {
                return nil
            }
            return (key, transform(row, day))
        }
        .sorted { $0.key < $1.key }
    }

    /// Marque supprimés les doublons d'un jour ; la marque part dans iCloud.
    private func markDeleted<Rows: Sequence>(_ rows: Rows, at date: Date) where Rows.Element: StoredSoftDeletable {
        for row in rows {
            row.deletedAt = date
            row.updatedAt = date
        }
    }
}

/// Une ligne synchronisée qu'on supprime en la marquant.
protocol StoredSoftDeletable: AnyObject {
    var deletedAt: Date? { get set }
    var updatedAt: Date { get set }
}

extension StoredDailyRecovery: StoredSoftDeletable {}
extension StoredCheckIn: StoredSoftDeletable {}
