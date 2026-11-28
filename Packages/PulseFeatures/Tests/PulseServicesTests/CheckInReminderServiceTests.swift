import Foundation
import PulseDomain
import PulseServices
import Testing

/// Mercredi 18 novembre 2026, 6 h : un profil sans montre, onboardé le 1er novembre, réveil en semaine à 7 h.
struct CheckInReminderServiceTests {
    private let calendar = TestClock.calendar
    private let profiles = InMemoryProfileRepository()
    private let recovery = InMemoryRecoveryRepository(calendar: TestClock.calendar)
    private let cache = InMemoryHealthSampleCache()
    private let scheduler = StubCheckInReminderScheduler()
    private let store = InMemoryCheckInReminderStore()
    private let clock = MutableClock("2026-11-18T06:00")

    private func service() -> CheckInReminderService {
        let clock = clock
        let recovery = recovery
        let calendar = calendar
        return CheckInReminderService(
            store: store, profiles: profiles, recovery: recovery, cache: cache, scheduler: scheduler,
            notifications: StubNotificationAuthorizer(granted: true),
            saveCheckIn: { answers in
                try await recovery.save(CheckIn(day: clock.now, answers: answers, score: 50, createdAt: clock.now,
                                                updatedAt: clock.now))
            },
            calendar: calendar, now: { clock.now })
    }

    private func setUp() async throws {
        try await profiles.save(UserProfile(weekdayWakeMinutes: 7 * 60, onboardingCompletedAt: TestClock.date("2026-11-01T09:00")))
    }

    private func savedAnswers() async throws -> [CheckInAnswers] {
        try await recovery.checkIns(from: .distantPast, to: .distantFuture).map(\.answers)
    }

    private func watchSample(_ text: String) -> CachedHealthSample {
        let start = TestClock.date(text)
        return CachedHealthSample(kind: .sdnn, start: start, end: start, value: 60, healthKitUUID: text, fetchedAt: start)
    }

    @Test func remindersAreScheduledWithoutWatchData() async throws {
        try await setUp()
        await service().reschedule()
        let reminders = await scheduler.reminders
        #expect(reminders.count == CheckInReminderRule.horizonDays)
        #expect(reminders.first?.fireDate == TestClock.date("2026-11-18T07:00"))
        #expect(await scheduler.clearedDelivered == false)
    }

    @Test func recentWatchDataRemovesThem() async throws {
        try await setUp()
        try await cache.apply(HealthSampleChanges(kind: .sdnn, added: [watchSample("2026-11-17T06:30")], deletedHealthKitUUIDs: [],
                                                  anchor: Data("a".utf8), isFullRead: true))
        await service().reschedule()
        #expect(await scheduler.reminders.isEmpty)
        #expect(await scheduler.clearedDelivered)
    }

    @Test func aMeasuredScoreTodaySkipsToday() async throws {
        try await setUp()
        let now = TestClock.date("2026-11-18T06:00")
        try await recovery.save(DailyRecovery(day: now, score: 70, category: .normal, isEstimated: false, calibration: .ready,
                                              createdAt: now, updatedAt: now))
        await service().reschedule()
        #expect(await scheduler.reminders.first?.day == TestClock.date("2026-11-19T00:00"))
        #expect(await scheduler.clearedDelivered)
    }

    @Test func aQuickAnswerSavesTheCheckInAndClearsToday() async throws {
        try await setUp()
        let service = service()
        await service.reschedule()
        #expect(await service.answer(.tired, day: TestClock.date("2026-11-18T00:00")))
        #expect(try await savedAnswers() == [CheckInQuickAnswer.tired.answers])
        #expect(await scheduler.reminders.first?.day == TestClock.date("2026-11-19T00:00"))
        #expect(await scheduler.clearedDelivered)
    }

    @Test func aRescheduleAfterTheReminderKeepsItWhileTheCheckInIsMissing() async throws {
        try await setUp()
        clock.set("2026-11-18T08:20")
        await service().reschedule()
        #expect(await scheduler.reminders.first?.day == TestClock.date("2026-11-19T00:00"))
        #expect(await scheduler.clearedDelivered == false, "Le rappel de 7 h reste dans le centre de notifications")
    }

    @Test func turningTheReminderOffClearsTheDeliveredOne() async throws {
        try await setUp()
        clock.set("2026-11-18T08:20")
        await service().setEnabled(false)
        #expect(await scheduler.clearedDelivered)
    }

    @Test func anAnswerFromAnotherDayIsIgnored() async throws {
        try await setUp()
        #expect(await service().answer(.good, day: TestClock.date("2026-11-17T00:00")) == false)
        #expect(try await savedAnswers().isEmpty)
        #expect(await scheduler.replaceCount == 1, "Les rappels sont tout de même replanifiés, et leur suite prolongée")
        #expect(await scheduler.reminders.first?.day == TestClock.date("2026-11-18T00:00"))
    }

    @Test func settingsAreKeptAndApplied() async throws {
        try await setUp()
        let service = service()
        await service.setChosenMinutes(6 * 60 + 30)
        #expect(await scheduler.reminders.first?.fireDate == TestClock.date("2026-11-18T06:30"))
        await service.setEnabled(false)
        #expect(await scheduler.reminders.isEmpty)
        #expect(service.settings == CheckInReminderSettings(enabled: false, chosenMinutes: 6 * 60 + 30))
    }

    @Test func userDefaultsStoreDefaultsToEnabledAtWakeTime() {
        let suite = "fr.seonay.pulse.tests.checkin.\(UUID().uuidString)"
        defer { UserDefaults().removePersistentDomain(forName: suite) }
        let store = UserDefaultsCheckInReminderStore(suiteName: suite)
        #expect(store.settings == CheckInReminderSettings())
        store.save(CheckInReminderSettings(enabled: false, chosenMinutes: 420))
        #expect(UserDefaultsCheckInReminderStore(suiteName: suite).settings == CheckInReminderSettings(enabled: false, chosenMinutes: 420))
        store.save(CheckInReminderSettings(enabled: true, chosenMinutes: nil))
        #expect(store.settings == CheckInReminderSettings())
    }
}
