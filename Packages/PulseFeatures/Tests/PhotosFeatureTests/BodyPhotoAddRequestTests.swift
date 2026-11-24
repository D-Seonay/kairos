import Foundation
@testable import PhotosFeature
import PulseDomain
import PulseServices
import Testing

/// La demande d'ajout : le jour qu'une case vide complète, et la pose que « + » propose.
@MainActor
struct BodyPhotoAddRequestTests: BodyPhotosModelTesting {
    let service = Self.makeService()
    private let calendar = PhotosTestClock.calendar

    @Test func emptySlotOfAnOlderDayDatesThePhotoThatDay() {
        let day = PhotosTestClock.date("2026-11-01T00:00")
        let request = BodyPhotoAddRequest(pose: .side, day: day)
        #expect(request.takenAt(proposed: PhotosTestClock.date("2026-11-20T12:00"), calendar: calendar) == day)
    }

    @Test func emptySlotKeepsThePhotoTimeOnThatDay() {
        let request = BodyPhotoAddRequest(pose: .side, day: PhotosTestClock.date("2026-11-01T00:00"))
        let proposed = PhotosTestClock.date("2026-11-01T08:30")
        #expect(request.takenAt(proposed: proposed, calendar: calendar) == proposed)
    }

    @Test func plusKeepsThePhotoDate() {
        let proposed = PhotosTestClock.date("2026-10-12T18:00")
        #expect(BodyPhotoAddRequest(pose: .front).takenAt(proposed: proposed, calendar: calendar) == proposed)
    }

    @Test func emptySlotDayIsTheOneTheReplaceRuleChecks() async throws {
        try await seed(.front, "2026-11-01T08:00")
        let model = await unlockedModel(StubOwnerAuthentication())
        let day = try #require(model.days.first)
        let request = BodyPhotoAddRequest(pose: .side, day: day.day)
        let takenAt = request.takenAt(proposed: model.today, calendar: calendar)
        #expect(await model.photoToReplace(pose: .side, on: takenAt) == nil)
        let draft = try #require(await model.prepare(TestImages.jpeg()))
        #expect(await model.save(draft, pose: .side, takenAt: takenAt))
        #expect(model.days.count == 1)
        #expect(model.days.first?.photos[.side] != nil)
    }

    @Test func plusProposesTheFirstPoseMissingToday() async throws {
        try await seed(.front, "2026-11-20T08:00")
        try await seed(.back, "2026-11-01T08:00")
        let model = await unlockedModel(StubOwnerAuthentication())
        #expect(BodyPhotoAddRequest.next(in: model.days, today: model.today, calendar: calendar).pose == .side)
        #expect(BodyPhotoAddRequest.next(in: model.days, today: model.today, calendar: calendar).day == nil)
    }

    @Test func plusProposesFrontWithoutPhotoTodayOrWhenTheDayIsFull() async throws {
        try await seed(.side, "2026-11-01T08:00")
        let model = await unlockedModel(StubOwnerAuthentication())
        #expect(BodyPhotoAddRequest.next(in: model.days, today: model.today, calendar: calendar).pose == .front)
        for pose in BodyPose.allCases { try await seed(pose, "2026-11-20T09:00") }
        await model.appear()
        #expect(BodyPhotoAddRequest.next(in: model.days, today: model.today, calendar: calendar).pose == .front)
    }
}
