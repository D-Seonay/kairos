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
// swiftlint:enable force_unwrapping
