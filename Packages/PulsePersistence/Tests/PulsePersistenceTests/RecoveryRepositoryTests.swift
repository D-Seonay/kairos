// swiftlint:disable force_unwrapping
import Foundation
import PulseDomain
@testable import PulsePersistence
import SwiftData
import Testing

@Test func recoverySaveReplacesSameLocalDay() async throws {   // Review Focus 5
    let repo = SwiftDataRecoveryRepository(modelContainer: try TestContainer.make(), calendar: Fixed.calendar)
    let cal = Fixed.calendar
    let today = cal.startOfDay(for: Date())
    let late = cal.date(bySettingHour: 23, minute: 59, second: 0, of: today)!
    let early = cal.date(bySettingHour: 0, minute: 1, second: 0, of: today)!
    let first = Sample.recovery(day: late, score: 50)
    try await repo.save(first)
    try await repo.save(Sample.recovery(day: early, score: 70))
    let all = try await repo.dailyRecoveries(from: today, to: cal.date(byAdding: .day, value: 1, to: today)!)
    #expect(all.count == 1 && all[0].score == 70 && all[0].day == today)
    #expect(all[0].id == first.id && all[0].createdAt == first.createdAt)
    let context = ModelContext(repo.modelContainer)
    #expect(try context.fetchCount(FetchDescriptor<StoredDailyRecovery>()) == 1)
}

@Test func saveKeepsSleepStagesInTheLocalReading() async throws {
    let repo = SwiftDataRecoveryRepository(modelContainer: try TestContainer.make(), calendar: Fixed.calendar)
    let cal = Fixed.calendar
    let today = cal.startOfDay(for: Fixed.t0)
    var recovery = Sample.recovery(day: today)
    recovery.coreMinutes = 300
    recovery.remMinutes = 60
    recovery.unspecifiedMinutes = 0
    recovery.awakeMinutes = 10
    try await repo.save(recovery)
    let read = try await repo.dailyRecoveries(from: today, to: cal.date(byAdding: .day, value: 1, to: today)!)
    #expect(read.count == 1)
    #expect(read[0].coreMinutes == 300 && read[0].remMinutes == 60 && read[0].unspecifiedMinutes == 0 && read[0].awakeMinutes == 10)
    let context = ModelContext(repo.modelContainer)
    let reading = try #require(try context.fetch(FetchDescriptor<StoredRecoveryReading>()).first)
    #expect(reading.coreMinutes == 300 && reading.awakeMinutes == 10)
}

/// Une nuit avec phases rattachée à `day`, de 420 min par défaut comme `Sample.recovery`.
private func stagedNight(day: Date, asleep: Int = 420) -> NightSample {
    NightSample(day: day, sdnnMs: nil, restingHeartRate: nil,
                sleep: SleepSummary(asleepMinutes: asleep, deepMinutes: 80, coreMinutes: 250, remMinutes: 90,
                                    unspecifiedMinutes: 0, awakeMinutes: 12))
}

@Test func backfillFillsAReadingWithoutStagesWhenTotalsMatch() async throws {
    let repo = SwiftDataRecoveryRepository(modelContainer: try TestContainer.make(), calendar: Fixed.calendar)
    let today = Fixed.calendar.startOfDay(for: Fixed.t0)
    try await repo.save(Sample.recovery(day: today))   // 420 min, sans phases
    try await repo.backfillSleepStages([stagedNight(day: today)])
    let read = try await repo.dailyRecoveries(from: today, to: Fixed.calendar.date(byAdding: .day, value: 1, to: today)!)
    #expect(read.count == 1)
    #expect(read[0].coreMinutes == 250 && read[0].remMinutes == 90 && read[0].unspecifiedMinutes == 0 && read[0].awakeMinutes == 12)
    #expect(read[0].asleepMinutes == 420 && read[0].deepMinutes == 80)
}

@Test func backfillSkipsAReadingWhoseTotalNoLongerMatches() async throws {
    let repo = SwiftDataRecoveryRepository(modelContainer: try TestContainer.make(), calendar: Fixed.calendar)
    let today = Fixed.calendar.startOfDay(for: Fixed.t0)
    try await repo.save(Sample.recovery(day: today))   // 420 min enregistrées
    try await repo.backfillSleepStages([stagedNight(day: today, asleep: 450)])
    let read = try await repo.dailyRecoveries(from: today, to: Fixed.calendar.date(byAdding: .day, value: 1, to: today)!)
    #expect(read[0].coreMinutes == nil && read[0].awakeMinutes == nil)
}

/// Le total est resté le même mais le profond a changé (phases arrivées après le figeage, sur une nuit enregistrée sans phases) :
/// les phases n'iraient pas avec le profond enregistré, la lecture reste sans phases.
@Test func backfillSkipsAReadingWhoseDeepNoLongerMatches() async throws {
    let repo = SwiftDataRecoveryRepository(modelContainer: try TestContainer.make(), calendar: Fixed.calendar)
    let today = Fixed.calendar.startOfDay(for: Fixed.t0)
    var recovery = Sample.recovery(day: today)   // 420 min
    recovery.deepMinutes = nil
    try await repo.save(recovery)
    try await repo.backfillSleepStages([stagedNight(day: today)])   // 420 min, profond 80
    let read = try await repo.dailyRecoveries(from: today, to: Fixed.calendar.date(byAdding: .day, value: 1, to: today)!)
    #expect(read[0].coreMinutes == nil && read[0].deepMinutes == nil)
}

@Test func backfillNeverOverwritesStoredStages() async throws {
    let repo = SwiftDataRecoveryRepository(modelContainer: try TestContainer.make(), calendar: Fixed.calendar)
    let today = Fixed.calendar.startOfDay(for: Fixed.t0)
    var recovery = Sample.recovery(day: today)
    recovery.coreMinutes = 200
    recovery.remMinutes = 140
    recovery.unspecifiedMinutes = 0
    recovery.awakeMinutes = 5
    try await repo.save(recovery)
    try await repo.backfillSleepStages([stagedNight(day: today)])
    let read = try await repo.dailyRecoveries(from: today, to: Fixed.calendar.date(byAdding: .day, value: 1, to: today)!)
    #expect(read[0].coreMinutes == 200 && read[0].remMinutes == 140 && read[0].awakeMinutes == 5)
}

/// Toute la plage en une fois : chaque nuit va à sa lecture, une lecture sans nuit, une lecture hors plage, une lecture qui a
/// déjà ses phases et une nuit sans lecture ne changent rien.
@Test func backfillFillsEveryMatchingReadingOfTheRange() async throws {
    let repo = SwiftDataRecoveryRepository(modelContainer: try TestContainer.make(), calendar: Fixed.calendar)
    let cal = Fixed.calendar
    let today = cal.startOfDay(for: Fixed.t0)
    func day(_ offset: Int) -> Date { cal.date(byAdding: .day, value: offset, to: today)! }
    for offset in [-10, -6, -5, -3, -1, 0] {
        try await repo.save(Sample.recovery(day: day(offset)))   // 420 min, profond 80, sans phases
    }
    var staged = Sample.recovery(day: day(-3))
    staged.coreMinutes = 200
    staged.remMinutes = 140
    staged.unspecifiedMinutes = 0
    staged.awakeMinutes = 5
    try await repo.save(staged)
    // Nuits à phases : -6, -3 (déjà à phases), -1, et -2 sans lecture ; -5 n'a qu'une nuit sans phases ; 0 aucune nuit.
    let unstaged = NightSample(day: day(-5), sdnnMs: nil, restingHeartRate: nil,
                               sleep: SleepSummary(asleepMinutes: 420, deepMinutes: nil))
    try await repo.backfillSleepStages([stagedNight(day: day(-1)), stagedNight(day: day(-6)), stagedNight(day: day(-3)),
                                        stagedNight(day: day(-2)), unstaged])
    let read = try await repo.dailyRecoveries(from: day(-10), to: day(1))
    let core = Dictionary(uniqueKeysWithValues: read.map { (cal.dateComponents([.day], from: day(0), to: $0.day).day!, $0.coreMinutes) })
    #expect(core == [-10: nil, -6: 250, -5: nil, -3: 200, -1: 250, 0: nil])
}

@Test func backfillWithoutStagedNightsChangesNothing() async throws {
    let repo = SwiftDataRecoveryRepository(modelContainer: try TestContainer.make(), calendar: Fixed.calendar)
    let today = Fixed.calendar.startOfDay(for: Fixed.t0)
    try await repo.save(Sample.recovery(day: today))
    try await repo.backfillSleepStages([])
    try await repo.backfillSleepStages([NightSample(day: today, sdnnMs: nil, restingHeartRate: nil, sleep: nil)])
    let read = try await repo.dailyRecoveries(from: today, to: Fixed.calendar.date(byAdding: .day, value: 1, to: today)!)
    #expect(read[0].coreMinutes == nil)
}

@Test func backfillLeavesTheSyncedRowUntouched() async throws {
    let repo = SwiftDataRecoveryRepository(modelContainer: try TestContainer.make(), calendar: Fixed.calendar)
    let today = Fixed.calendar.startOfDay(for: Fixed.t0)
    try await repo.save(Sample.recovery(day: today))
    let context = ModelContext(repo.modelContainer)
    let before = try #require(try context.fetch(FetchDescriptor<StoredDailyRecovery>()).first?.updatedAt)
    try await repo.backfillSleepStages([stagedNight(day: today)])
    let after = try #require(try ModelContext(repo.modelContainer).fetch(FetchDescriptor<StoredDailyRecovery>()).first?.updatedAt)
    #expect(after == before)
}

@Test func recoveriesSortedByDayWithinRange() async throws {
    let repo = SwiftDataRecoveryRepository(modelContainer: try TestContainer.make(), calendar: Fixed.calendar)
    let cal = Fixed.calendar
    let today = cal.startOfDay(for: Date())
    for offset in [-1, -3, -2] {
        try await repo.save(Sample.recovery(day: cal.date(byAdding: .day, value: offset, to: today)!, score: Double(60 + offset)))
    }
    let found = try await repo.dailyRecoveries(from: cal.date(byAdding: .day, value: -2, to: today)!, to: today)
    #expect(found.map(\.score) == [58, 59])
}

@Test func checkInSaveReplacesSameDay() async throws {
    let repo = SwiftDataRecoveryRepository(modelContainer: try TestContainer.make(), calendar: Fixed.calendar)
    let cal = Fixed.calendar
    let today = cal.startOfDay(for: Date())
    try await repo.save(Sample.checkIn(day: cal.date(bySettingHour: 7, minute: 0, second: 0, of: today)!))
    var second = Sample.checkIn(day: cal.date(bySettingHour: 9, minute: 0, second: 0, of: today)!)
    second.score = 40
    try await repo.save(second)
    let found = try await repo.checkIns(from: today, to: cal.date(byAdding: .day, value: 1, to: today)!)
    #expect(found.count == 1 && found[0].score == 40 && found[0].day == today)
}

@Test func recoveryDayUsesInjectedCalendar() async throws {
    var auckland = Calendar(identifier: .gregorian)
    auckland.timeZone = try #require(TimeZone(identifier: "Pacific/Auckland"))
    let repo = SwiftDataRecoveryRepository(modelContainer: try TestContainer.make(), calendar: auckland)
    let instant = try Date("2026-11-01T11:30:00Z", strategy: .iso8601)
    try await repo.save(Sample.recovery(day: instant, score: 64))
    let found = try await repo.dailyRecoveries(from: .distantPast, to: .distantFuture)
    #expect(found.map(\.day) == [try Date("2026-11-01T11:00:00Z", strategy: .iso8601)])
}

@Test func originalSessionChosenRoundTrips() async throws {
    let repo = SwiftDataRecoveryRepository(modelContainer: try TestContainer.make(), calendar: Fixed.calendar)
    var recovery = Sample.recovery()
    recovery.originalSessionChosen = true
    try await repo.save(recovery)
    let found = try await repo.dailyRecoveries(from: .distantPast, to: .distantFuture)
    #expect(found.map(\.originalSessionChosen) == [true])
}
@Test func savedRecoveryKeepsRawValuesOffTheSyncedStore() async throws {
    let box = try ModelContainerBox()
    let repository = SwiftDataRecoveryRepository(modelContainer: box.container, calendar: Fixed.calendar)
    try await repository.save(Sample.recovery())
    let context = ModelContext(box.container)
    let synced = try #require(try context.fetch(FetchDescriptor<StoredDailyRecovery>()).first)
    #expect(synced.sdnnMs == nil && synced.sdnnBaselineMs == nil && synced.restingHeartRate == nil)
    #expect(synced.restingHeartRateBaseline == nil && synced.asleepMinutes == nil && synced.deepMinutes == nil)
    #expect(synced.score == 72 && synced.hrvScore == 80)
    let reading = try #require(try context.fetch(FetchDescriptor<StoredRecoveryReading>()).first)
    #expect(reading.sdnnMs == 50 && reading.deepMinutes == 80)
    let read = try await repository.dailyRecoveries(from: .distantPast, to: .distantFuture)
    #expect(read.first?.sdnnMs == 50 && read.first?.restingHeartRateBaseline == 50 && read.first?.asleepMinutes == 420)
}

@Test func rewritingTheDayUpdatesItsReadingInPlace() async throws {
    let box = try ModelContainerBox()
    let repository = SwiftDataRecoveryRepository(modelContainer: box.container, calendar: Fixed.calendar)
    var recovery = Sample.recovery()
    try await repository.save(recovery)
    recovery.sdnnMs = 55
    try await repository.save(recovery)
    let readings = try ModelContext(box.container).fetch(FetchDescriptor<StoredRecoveryReading>())
    #expect(readings.count == 1 && readings.first?.sdnnMs == 55)
}

@Test func recoveryWithoutRawValuesDropsTheReading() async throws {
    let box = try ModelContainerBox()
    let repository = SwiftDataRecoveryRepository(modelContainer: box.container, calendar: Fixed.calendar)
    var recovery = Sample.recovery()
    try await repository.save(recovery)
    recovery.sdnnMs = nil
    recovery.sdnnBaselineMs = nil
    recovery.restingHeartRate = nil
    recovery.restingHeartRateBaseline = nil
    recovery.asleepMinutes = nil
    recovery.deepMinutes = nil
    try await repository.save(recovery)
    #expect(try ModelContext(box.container).fetchCount(FetchDescriptor<StoredRecoveryReading>()) == 0)
    let read = try await repository.dailyRecoveries(from: .distantPast, to: .distantFuture)
    #expect(read.count == 1 && read[0].sdnnMs == nil && read[0].asleepMinutes == nil && read[0].deepMinutes == nil)
}

@Test func readingsJoinTheirOwnDay() async throws {
    let box = try ModelContainerBox()
    let repository = SwiftDataRecoveryRepository(modelContainer: box.container, calendar: Fixed.calendar)
    let today = Fixed.calendar.startOfDay(for: Date())
    let yesterday = try #require(Fixed.calendar.date(byAdding: .day, value: -1, to: today))
    var older = Sample.recovery(day: yesterday)
    older.sdnnMs = 41
    older.asleepMinutes = 390
    try await repository.save(older)
    try await repository.save(Sample.recovery(day: today))
    let read = try await repository.dailyRecoveries(from: .distantPast, to: .distantFuture)
    #expect(read.count == 2)
    #expect(read[0].sdnnMs == 41 && read[0].asleepMinutes == 390)
    #expect(read[1].sdnnMs == 50 && read[1].asleepMinutes == 420)
}

@Test func recoveryWithoutReadingKeepsLegacyRawValues() async throws {
    let box = try ModelContainerBox()
    let repository = SwiftDataRecoveryRepository(modelContainer: box.container, calendar: Fixed.calendar)
    let legacy = Sample.recovery(day: Fixed.calendar.startOfDay(for: Fixed.t0))
    let context = ModelContext(box.container)
    let row = StoredDailyRecovery(legacy)
    row.sdnnMs = 61   // ancienne ligne : valeurs brutes encore dans le magasin synchronisé
    context.insert(row)
    try context.save()
    let read = try await repository.dailyRecoveries(from: .distantPast, to: .distantFuture)
    #expect(read.first?.sdnnMs == 61)
}

@Test func savingOverALegacyRowClearsItsRawValues() async throws {
    let box = try ModelContainerBox()
    let repository = SwiftDataRecoveryRepository(modelContainer: box.container, calendar: Fixed.calendar)
    var recovery = Sample.recovery(day: Fixed.calendar.startOfDay(for: Fixed.t0))
    let context = ModelContext(box.container)
    let row = StoredDailyRecovery(recovery)
    row.sdnnMs = 61   // ancienne ligne : valeurs brutes encore dans le magasin synchronisé, pas de lecture locale
    context.insert(row)
    try context.save()
    recovery.sdnnMs = nil
    recovery.sdnnBaselineMs = nil
    recovery.restingHeartRate = nil
    recovery.restingHeartRateBaseline = nil
    recovery.asleepMinutes = nil
    recovery.deepMinutes = nil
    try await repository.save(recovery)
    let check = ModelContext(box.container)
    #expect(try check.fetchCount(FetchDescriptor<StoredRecoveryReading>()) == 0)
    let synced = try #require(try check.fetch(FetchDescriptor<StoredDailyRecovery>()).first)
    #expect(synced.sdnnMs == nil && synced.sdnnBaselineMs == nil && synced.restingHeartRate == nil)
    #expect(synced.restingHeartRateBaseline == nil && synced.asleepMinutes == nil && synced.deepMinutes == nil)
    let read = try await repository.dailyRecoveries(from: .distantPast, to: .distantFuture)
    #expect(read.count == 1 && read[0].sdnnMs == nil)
}
// swiftlint:enable force_unwrapping
