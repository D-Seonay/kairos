import Foundation
@testable import ProfileFeature
import PulseDomain
import PulseServices
import Testing

/// Le rappel de check-in dans les notifications des Paramètres.
extension SettingsModelTests {
    private func checkInService(store: InMemoryCheckInReminderStore,
                                scheduler: StubCheckInReminderScheduler) -> CheckInReminderService {
        let calendar = ProfileTestClock.calendar
        return CheckInReminderService(store: store, profiles: profiles, recovery: InMemoryRecoveryRepository(calendar: calendar),
                                      cache: cache, scheduler: scheduler, notifications: StubNotificationAuthorizer(granted: true),
                                      saveCheckIn: { _ in }, calendar: calendar, now: { ProfileTestClock.now })
    }

    @Test func checkInReminderIsReadAndChanged() async throws {
        _ = try await storeProfile()
        let store = InMemoryCheckInReminderStore()
        let scheduler = StubCheckInReminderScheduler()
        var environment = environment()
        environment.checkInReminders = checkInService(store: store, scheduler: scheduler)
        let model = SettingsModel(environment: environment) { _ in }
        await model.load()
        #expect(model.checkInReminder == CheckInReminderSettings())

        await model.setCheckInReminderMinutes(7 * 60)
        #expect(model.checkInReminder?.chosenMinutes == 7 * 60 && store.settings.chosenMinutes == 7 * 60)
        await model.setCheckInReminderEnabled(false)
        #expect(model.checkInReminder == CheckInReminderSettings(enabled: false, chosenMinutes: 7 * 60))
        #expect(await scheduler.replaceCount == 2)
    }

    @Test func withoutServiceThereIsNoCheckInReminderRow() async throws {
        _ = try await storeProfile()
        let model = SettingsModel(environment: environment()) { _ in }
        await model.load()
        #expect(model.checkInReminder == nil)
    }
}
