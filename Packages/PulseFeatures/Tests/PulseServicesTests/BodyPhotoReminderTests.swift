import Foundation
import PulseDomain
import PulseServices
import Testing

struct BodyPhotoReminderTests {
    private let calendar = TestClock.calendar
    private let now = TestClock.date("2026-11-20T12:00")

    private func dates(_ interval: BodyPhotoReminderInterval, last: String?, now: Date? = nil) -> [Date] {
        BodyPhotoReminderPlanner.dates(interval: interval, lastPhoto: last.map(TestClock.date), now: now ?? self.now,
                                       calendar: calendar)
    }

    @Test func offPlansNothing() {
        #expect(dates(.off, last: "2026-11-10T08:00").isEmpty)
    }

    @Test func everyTwoWeeksStartsFromTheLastPhotoAtNineAndRepeats() {
        #expect(dates(.everyTwoWeeks, last: "2026-11-10T19:30") == [
            TestClock.date("2026-11-24T09:00"), TestClock.date("2026-12-08T09:00"), TestClock.date("2026-12-22T09:00")
        ])
    }

    @Test func monthlyFollowsTheCalendarMonth() {
        #expect(dates(.monthly, last: "2026-11-15T08:00") == [
            TestClock.date("2026-12-15T09:00"), TestClock.date("2027-01-15T09:00"), TestClock.date("2027-02-15T09:00")
        ])
    }

    @Test func withoutAPhotoTheFirstReminderComesOnePeriodFromNow() {
        #expect(dates(.everyTwoWeeks, last: nil).first == TestClock.date("2026-12-04T09:00"))
    }

    /// Une dernière photo trop ancienne : le rappel arrive au prochain 9 h, puis reprend son rythme.
    @Test func anOverdueReminderComesAtTheNextNineOClock() {
        #expect(dates(.monthly, last: "2026-08-01T08:00") == [
            TestClock.date("2026-11-21T09:00"), TestClock.date("2026-12-21T09:00"), TestClock.date("2027-01-21T09:00")
        ])
        let early = TestClock.date("2026-11-20T07:00")
        #expect(dates(.everyTwoWeeks, last: "2026-10-01T08:00", now: early).first == TestClock.date("2026-11-20T09:00"))
    }

    /// Prendre une photo aujourd'hui repousse le rappel d'une période entière.
    @Test func aNewPhotoPushesTheNextReminder() {
        let before = dates(.everyTwoWeeks, last: "2026-11-10T08:00")
        let after = dates(.everyTwoWeeks, last: "2026-11-20T11:00")
        #expect(before.first == TestClock.date("2026-11-24T09:00"))
        #expect(after.first == TestClock.date("2026-12-04T09:00"))
    }

    @Test func remindersSaveTheSettingAskForNotificationsAndReplaceThePlannedDates() async {
        let store = InMemoryBodyPhotoReminderStore()
        let scheduler = StubBodyPhotoReminderScheduler()
        let notifications = StubNotificationAuthorizer(granted: true)
        let reminders = BodyPhotoReminders(store: store, scheduler: scheduler, notifications: notifications, calendar: calendar)

        await reminders.setInterval(.everyTwoWeeks, lastPhoto: TestClock.date("2026-11-10T08:00"), now: now)
        #expect(store.interval == .everyTwoWeeks)
        #expect(await notifications.requestCount == 1)
        #expect(await scheduler.dates.first == TestClock.date("2026-11-24T09:00"))

        await reminders.setInterval(.off, lastPhoto: nil, now: now)
        #expect(await scheduler.dates.isEmpty)
        #expect(await notifications.requestCount == 1)
    }

    /// Les trois échéances passées, le retour au premier plan relance le rappel depuis maintenant ; rien ne bouge tant qu'une
    /// échéance attend, ni quand le rappel est désactivé.
    @Test func foregroundResumesTheReminderOnlyWhenNothingIsPending() async {
        let store = InMemoryBodyPhotoReminderStore()
        let scheduler = StubBodyPhotoReminderScheduler()
        let reminders = BodyPhotoReminders(store: store, scheduler: scheduler, notifications: nil, calendar: calendar)

        await reminders.resumeIfIdle(now: now)
        #expect(await scheduler.replaceCount == 0)

        await reminders.setInterval(.monthly, lastPhoto: TestClock.date("2026-11-15T08:00"), now: now)
        await reminders.resumeIfIdle(now: now)
        #expect(await scheduler.replaceCount == 1)

        await scheduler.deliverAll()
        let later = TestClock.date("2027-02-16T18:00")
        await reminders.resumeIfIdle(now: later)
        #expect(await scheduler.replaceCount == 2)
        #expect(await scheduler.dates == [
            TestClock.date("2027-03-16T09:00"), TestClock.date("2027-04-16T09:00"), TestClock.date("2027-05-16T09:00")
        ])
    }

    /// « Tous les mois » puis aussitôt « Désactivé », pendant que la demande d'autorisation du premier attend : rien ne reste.
    @Test func quickSwitchToOffLeavesNoReminder() async {
        let store = InMemoryBodyPhotoReminderStore()
        let scheduler = StubBodyPhotoReminderScheduler()
        let gate = GatedAuthorizer()
        let reminders = BodyPhotoReminders(store: store, scheduler: scheduler, notifications: gate, calendar: calendar)
        let now = now
        let monthly = Task { await reminders.setInterval(.monthly, lastPhoto: nil, now: now) }
        while await !gate.isWaiting { await Task.yield() }
        await reminders.setInterval(.off, lastPhoto: nil, now: now)
        await gate.open()
        await monthly.value
        #expect(store.interval == .off)
        #expect(await scheduler.dates.isEmpty)
    }

    @Test func deniedNotificationsAreReported() async {
        let denied = BodyPhotoReminders(store: InMemoryBodyPhotoReminderStore(), scheduler: StubBodyPhotoReminderScheduler(),
                                        notifications: nil, notificationStatus: { .denied }, calendar: calendar)
        let allowed = BodyPhotoReminders(store: InMemoryBodyPhotoReminderStore(), scheduler: StubBodyPhotoReminderScheduler(),
                                         notifications: nil, notificationStatus: { .authorized }, calendar: calendar)
        #expect(await denied.notificationsDenied())
        #expect(await !allowed.notificationsDenied())
    }
}

/// Une autorisation qui attend `open()` avant de répondre.
private actor GatedAuthorizer: NotificationAuthorizing {
    private var continuation: CheckedContinuation<Void, Never>?
    private(set) var isWaiting = false

    func requestAuthorization() async -> Bool {
        isWaiting = true
        await withCheckedContinuation { continuation = $0 }
        return true
    }

    func open() {
        continuation?.resume()
        continuation = nil
    }
}
