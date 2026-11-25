import Foundation
@testable import PhotosFeature
import PulseDomain
import PulseServices
import PulseTestSupport
import Testing

/// Le rappel de reprendre des photos de corps : réglé dans la section déverrouillée, replanifié à chaque photo.
@MainActor
struct BodyPhotosReminderTests: BodyPhotosModelTesting {
    let service = Self.makeService()
    private let store = InMemoryBodyPhotoReminderStore()
    private let scheduler = StubBodyPhotoReminderScheduler()

    private func reminderModel(_ authentication: StubOwnerAuthentication) -> BodyPhotosModel {
        let reminders = BodyPhotoReminders(store: store, scheduler: scheduler, notifications: nil,
                                           calendar: PhotosTestClock.calendar)
        return BodyPhotosModel(service: service, authentication: authentication, lock: InMemoryBodyPhotoLockStore(),
                               reminders: reminders, calendar: PhotosTestClock.calendar,
                               now: { PhotosTestClock.date("2026-11-20T12:00") })
    }

    @Test func withoutRemindersTheSettingIsNotOffered() async {
        let model = await unlockedModel(StubOwnerAuthentication())
        #expect(!model.offersReminder)
        #expect(model.reminderInterval == .off)
    }

    @Test func choosingAnIntervalPlansFromTheLastPhoto() async throws {
        try await seed(.front, "2026-11-10T08:00")
        try await seed(.side, "2026-10-01T08:00")
        let model = reminderModel(StubOwnerAuthentication())
        await model.appear()
        await model.setReminderInterval(.everyTwoWeeks)
        #expect(model.reminderInterval == .everyTwoWeeks)
        #expect(store.interval == .everyTwoWeeks)
        #expect(await scheduler.dates.first == PhotosTestClock.date("2026-11-24T09:00"))
    }

    @Test func lockedSectionChangesNothing() async {
        let authentication = StubOwnerAuthentication(succeeds: false)
        let model = reminderModel(authentication)
        await model.appear()
        await model.setReminderInterval(.monthly)
        #expect(model.reminderInterval == .off)
        #expect(await scheduler.replaceCount == 0)
    }

    @Test func aNewPhotoPushesTheReminder() async throws {
        try await seed(.front, "2026-11-10T08:00")
        let model = reminderModel(StubOwnerAuthentication())
        await model.appear()
        await model.setReminderInterval(.everyTwoWeeks)
        let draft = try #require(await model.prepare(TestImages.jpeg()))
        #expect(await model.save(draft, pose: .back, takenAt: PhotosTestClock.date("2026-11-20T11:00")))
        #expect(await scheduler.dates.first == PhotosTestClock.date("2026-12-04T09:00"))
        #expect(await scheduler.replaceCount == 2)
    }

    @Test func photosDoNotPlanAnythingWhileTheReminderIsOff() async throws {
        let model = reminderModel(StubOwnerAuthentication())
        await model.appear()
        let draft = try #require(await model.prepare(TestImages.jpeg()))
        #expect(await model.save(draft, pose: .front, takenAt: PhotosTestClock.date("2026-11-20T11:00")))
        #expect(await scheduler.replaceCount == 0)
    }

    @Test func deniedNotificationsShowUnderTheReminder() async {
        let reminders = BodyPhotoReminders(store: store, scheduler: scheduler, notifications: nil,
                                           notificationStatus: { .denied }, calendar: PhotosTestClock.calendar)
        let model = BodyPhotosModel(service: service, authentication: StubOwnerAuthentication(), lock: InMemoryBodyPhotoLockStore(),
                                    reminders: reminders, calendar: PhotosTestClock.calendar,
                                    now: { PhotosTestClock.date("2026-11-20T12:00") })
        #expect(!model.notificationsDenied)
        await model.refreshNotificationStatus()
        #expect(model.notificationsDenied)
    }
}
