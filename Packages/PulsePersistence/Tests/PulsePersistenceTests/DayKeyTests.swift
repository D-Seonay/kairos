import Foundation
import PulseDomain
@testable import PulsePersistence
import SwiftData
import Testing

private func calendar(_ identifier: String) -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: identifier) ?? .gmt
    return calendar
}

private let paris = calendar("Europe/Paris")
private let newYork = calendar("America/New_York")

/// Minuit du 27 novembre 2026 (ou d'un jour voisin) dans `calendar`.
private func midnight(_ day: Int = 27, in calendar: Calendar) -> Date {
    calendar.date(from: DateComponents(year: 2026, month: 11, day: day)) ?? .distantPast
}

@Test func theKeyIsTheCivilDateOfTheCalendar() {
    #expect(DayKey.key(for: midnight(in: paris), calendar: paris) == "2026-11-27")
    // Minuit à Paris, c'est encore le 26 à New York.
    #expect(DayKey.key(for: midnight(in: paris), calendar: newYork) == "2026-11-26")
    #expect(DayKey.date(for: "2026-11-27", calendar: newYork) == midnight(in: newYork))
    #expect(DayKey.date(for: "2026-02-03", calendar: paris) == paris.date(from: DateComponents(year: 2026, month: 2, day: 3)))
    #expect(DayKey.date(for: "pas une date", calendar: paris) == nil)
}

/// Un score et un check-in écrits à Paris se relisent à New York pour le même jour civil ; le score du jour réécrit à New York
/// remplace la ligne de Paris au lieu d'en créer une seconde.
@Test func aDayWrittenInParisIsTheSameDayInNewYork() async throws {
    let container = try TestContainer.make()
    let inParis = SwiftDataRecoveryRepository(modelContainer: container, calendar: paris)
    try await inParis.save(Sample.recovery(day: midnight(in: paris).addingTimeInterval(8 * 3_600), score: 60))
    try await inParis.save(Sample.checkIn(day: midnight(in: paris).addingTimeInterval(8 * 3_600)))

    let inNewYork = SwiftDataRecoveryRepository(modelContainer: container, calendar: newYork)
    let range = (from: midnight(in: newYork), to: midnight(28, in: newYork))
    let read = try await inNewYork.dailyRecoveries(from: range.from, to: range.to)
    #expect(read.map(\.score) == [60] && read.first?.day == midnight(in: newYork))
    #expect(read.first?.sdnnMs == 50)   // la lecture locale suit sa clé
    #expect(try await inNewYork.checkIns(from: range.from, to: range.to).map(\.day) == [midnight(in: newYork)])

    try await inNewYork.save(Sample.recovery(day: midnight(in: newYork).addingTimeInterval(7 * 3_600), score: 70))
    let context = ModelContext(container)
    let rows = try context.fetch(FetchDescriptor<StoredDailyRecovery>())
    #expect(rows.count == 1 && rows.first?.score == 70 && rows.first?.dayKey == "2026-11-27")
    #expect(try context.fetchCount(FetchDescriptor<StoredRecoveryReading>()) == 1)
    // Le jour d'avant et le jour d'après, à New York, restent vides.
    #expect(try await inNewYork.dailyRecoveries(from: midnight(26, in: newYork), to: midnight(in: newYork)).isEmpty)
    #expect(try await inNewYork.dailyRecoveries(from: midnight(28, in: newYork), to: midnight(29, in: newYork)).isEmpty)
}

/// Deux appareils hors ligne ont chacun écrit le même jour : iCloud ramène deux lignes. La plus récente se lit seule, et le
/// prochain enregistrement du jour marque l'autre supprimée (la marque part dans iCloud).
@Test func twoDevicesWritingTheSameDayReadAsOne() async throws {
    let container = try TestContainer.make()
    let context = ModelContext(container)
    for (score, updatedAt) in [(55.0, Fixed.t1), (65.0, Fixed.t2)] {
        var recovery = Sample.recovery(day: midnight(in: paris), score: score)
        recovery.id = UUID()
        recovery.updatedAt = updatedAt
        let row = StoredDailyRecovery(recovery)
        row.dayKey = "2026-11-27"
        context.insert(row)
        var checkIn = Sample.checkIn(day: midnight(in: paris))
        checkIn.score = score
        checkIn.updatedAt = updatedAt
        let checkInRow = StoredCheckIn(checkIn)
        checkInRow.dayKey = "2026-11-27"
        context.insert(checkInRow)
    }
    try context.save()

    let repo = SwiftDataRecoveryRepository(modelContainer: container, calendar: paris)
    let range = (from: midnight(in: paris), to: midnight(28, in: paris))
    #expect(try await repo.dailyRecoveries(from: range.from, to: range.to).map(\.score) == [65])
    #expect(try await repo.checkIns(from: range.from, to: range.to).map(\.score) == [65])

    try await repo.save(Sample.recovery(day: midnight(in: paris), score: 80))
    try await repo.save(Sample.checkIn(day: midnight(in: paris)))
    let after = ModelContext(container)
    let live = try after.fetch(FetchDescriptor<StoredDailyRecovery>(predicate: #Predicate { $0.deletedAt == nil }))
    #expect(live.map(\.score) == [80])
    #expect(try after.fetchCount(FetchDescriptor<StoredDailyRecovery>(predicate: #Predicate { $0.deletedAt != nil })) == 1)
    #expect(try after.fetchCount(FetchDescriptor<StoredCheckIn>(predicate: #Predicate { $0.deletedAt == nil })) == 1)
}

/// La réparation donne une clé aux lignes d'avant la V9 et ne garde que la plus récente de chaque jour ; repassée, elle ne
/// change plus rien.
@Test func theRepairKeysOldRowsAndKeepsTheNewestOfEachDay() throws {
    let container = try TestContainer.make()
    let context = ModelContext(container)
    let older = StoredDailyRecovery(Sample.recovery(day: midnight(in: paris), score: 50))
    older.updatedAt = Fixed.t1
    var newerRecovery = Sample.recovery(day: midnight(in: paris), score: 75)
    newerRecovery.id = UUID()
    let newer = StoredDailyRecovery(newerRecovery)
    newer.updatedAt = Fixed.t2
    let otherDay = StoredDailyRecovery(Sample.recovery(day: midnight(26, in: paris), score: 40))
    context.insert(older)
    context.insert(newer)
    context.insert(otherDay)
    context.insert(StoredRecoveryReading(day: midnight(in: paris), from: Sample.recovery(), at: Fixed.t1))
    context.insert(StoredRecoveryReading(day: midnight(in: paris).addingTimeInterval(3_600), from: Sample.recovery(), at: Fixed.t2))
    try context.save()

    #expect(try DayKeyRepair.run(in: context, calendar: paris, now: Fixed.t2.addingTimeInterval(60)))
    let live = try context.fetch(FetchDescriptor<StoredDailyRecovery>(predicate: #Predicate { $0.deletedAt == nil }))
    #expect(Set(live.map(\.score)) == [75, 40])
    #expect(live.allSatisfy { $0.dayKey != nil })
    #expect(older.deletedAt != nil)
    let readings = try context.fetch(FetchDescriptor<StoredRecoveryReading>())
    #expect(readings.count == 1 && readings.first?.updatedAt == Fixed.t2 && readings.first?.dayKey == "2026-11-27")
    #expect(try !DayKeyRepair.run(in: context, calendar: paris, now: Fixed.t2.addingTimeInterval(120)))
}

/// Une ligne d'avant la V9, sans clé, écrite à minuit de Paris : relue et réparée à New York, elle reste le 27, pas le 26.
@Test func anOldRowWithoutKeyKeepsItsDayInAnotherTimeZone() async throws {
    #expect(DayKey.effective(nil, day: midnight(in: paris), calendar: paris) == "2026-11-27")
    #expect(DayKey.effective(nil, day: midnight(in: paris), calendar: newYork) == "2026-11-27")
    #expect(DayKey.effective(nil, day: midnight(in: newYork), calendar: paris) == "2026-11-27")
    #expect(DayKey.effective(nil, day: midnight(in: calendar("Asia/Tokyo")), calendar: newYork) == "2026-11-27")
    #expect(DayKey.effective("2026-11-26", day: midnight(in: paris), calendar: paris) == "2026-11-26")

    let container = try TestContainer.make()
    let context = ModelContext(container)
    context.insert(StoredDailyRecovery(Sample.recovery(day: midnight(in: paris), score: 61)))
    try context.save()
    let inNewYork = SwiftDataRecoveryRepository(modelContainer: container, calendar: newYork)
    let read = try await inNewYork.dailyRecoveries(from: midnight(in: newYork), to: midnight(28, in: newYork))
    #expect(read.map(\.score) == [61])
    #expect(try DayKeyRepair.run(in: context, calendar: newYork, now: Fixed.t2))
    #expect(try context.fetch(FetchDescriptor<StoredDailyRecovery>()).map(\.dayKey) == ["2026-11-27"])
}
