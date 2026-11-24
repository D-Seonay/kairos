import Foundation
@testable import PhotosFeature
import PulseDomain
import PulseServices
import Testing

@MainActor
struct BodyPhotoCompareModelTests {
    private let calendar = PhotosTestClock.calendar
    private let measurements = InMemoryBodyMeasurementRepository()
    private let service: BodyPhotoService

    init() {
        service = BodyPhotoService(store: InMemoryBodyPhotoStore(), measurements: measurements,
                                   calendar: PhotosTestClock.calendar, timeZone: PhotosTestClock.calendar.timeZone,
                                   now: { PhotosTestClock.date("2026-11-20T12:00") })
    }

    private func photo(_ pose: BodyPose, _ date: String) -> BodyPhoto {
        let day = PhotosTestClock.date(date)
        return BodyPhoto(id: UUID(), pose: pose, takenAt: day, createdAt: day)
    }

    private func weighing(_ date: String, _ kg: Double) -> BodyMeasurement {
        let day = PhotosTestClock.date(date)
        return BodyMeasurement(date: day, weightKg: kg, source: .manual, createdAt: day, updatedAt: day)
    }

    private func makeModel(_ photos: [BodyPhoto]) -> BodyPhotoCompareModel {
        BodyPhotoCompareModel(service: service, photos: photos, calendar: calendar)
    }

    @Test func compareDefaultsToOldestAndNewest() {
        let oldest = photo(.front, "2026-08-01T08:00")
        let middle = photo(.front, "2026-09-30T08:00")
        let newest = photo(.front, "2026-10-28T08:00")
        let model = makeModel([middle, newest, oldest])
        #expect(model.pose == .front)
        #expect(model.before?.id == oldest.id)
        #expect(model.after?.id == newest.id)
        #expect(model.position == 0.5)
        #expect(!model.isSideBySide)
        #expect(model.candidates.map(\.id) == [newest.id, middle.id, oldest.id])
        #expect(model.apartText == "12 semaines d'écart")
    }

    @Test func compareListsOnlyComparablePoses() {
        let backBefore = photo(.back, "2026-08-01T08:00")
        let backAfter = photo(.back, "2026-10-28T08:00")
        let model = makeModel([photo(.side, "2026-08-01T08:00"), backBefore, backAfter, photo(.front, "2026-08-01T08:00"),
                               photo(.front, "2026-10-28T08:00")])
        #expect(model.poses == [.front, .back])
        model.pose = .back
        #expect(model.before?.id == backBefore.id)
        #expect(model.after?.id == backAfter.id)
        // Une pose sans deux dates n'est pas retenue.
        model.pose = .side
        #expect(model.pose == .back)
    }

    @Test func chooseOrdersTheDatesAndRefusesOneDay() async {
        let first = photo(.front, "2026-08-01T08:00")
        let second = photo(.front, "2026-09-30T08:00")
        let third = photo(.front, "2026-10-28T08:00")
        let model = makeModel([first, second, third])
        await model.choose(before: third, after: second)
        #expect(model.before?.id == second.id)
        #expect(model.after?.id == third.id)
        await model.choose(before: first, after: first)
        #expect(model.before?.id == second.id)
    }

    @Test func sliderLabelNamesBothDates() {
        let model = makeModel([photo(.front, "2026-08-01T08:00"), photo(.front, "2026-10-28T08:00")])
        #expect(model.sliderSpokenLabel == "Avant, 1er août · Après, 28 octobre")
        #expect(model.sliderSpokenValue == "50 %")
        model.increment()
        #expect(model.sliderSpokenValue == "60 %")
        for _ in 0..<10 { model.increment() }
        #expect(model.position == 1)
        for _ in 0..<12 { model.decrement() }
        #expect(model.position == 0)
        #expect(model.beforeTag == "1er août")
        #expect(model.afterTag == "28 octobre")
    }

    @Test func weightTileAbsentWithoutTrend() async throws {
        let model = makeModel([photo(.front, "2026-08-04T10:00"), photo(.front, "2026-10-30T10:00")])
        await model.refreshWeightChange()
        #expect(model.weightChange == nil)
        #expect(model.weightText == nil)
        try await measurements.save(weighing("2026-08-01T07:00", 70))
        await model.refreshWeightChange()
        #expect(model.weightChange == nil)
    }

    @Test func weightTileGivesTheSignedTrendChange() async throws {
        for weighing in [weighing("2026-08-01T07:00", 70), weighing("2026-10-28T07:00", 68.6)] {
            try await measurements.save(weighing)
        }
        let model = makeModel([photo(.front, "2026-08-04T10:00"), photo(.front, "2026-10-30T10:00")])
        await model.refreshWeightChange()
        #expect(try abs(#require(model.weightChange) - -1.4) < 0.01)
        #expect(model.weightText == "\u{2212}1,4 kg")
        #expect(model.weightSpoken == "Poids, tendance, moins 1,4 kilo")
    }

    @Test func signedKilosRoundsToATenth() {
        #expect(PhotoText.signedKilos(1.26) == "+1,3 kg")
        #expect(PhotoText.signedKilos(-0.04) == "0 kg")
        #expect(PhotoText.signedKilos(-2) == "\u{2212}2 kg")
    }
}
