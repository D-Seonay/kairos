import Foundation
import PulseDomain
import PulseServices
import Testing

struct PhotoRulesTests {
    private var calendar: Calendar { TestClock.calendar }

    private func session(_ source: SessionSource) -> WorkoutSession {
        let start = TestClock.date("2026-11-20T18:00")
        return WorkoutSession(startedAt: start, kind: .strength, source: source, status: .completed, title: "Séance",
                              createdAt: start, updatedAt: start)
    }

    private func photo(_ pose: BodyPose, _ date: String, createdAt: String? = nil) -> BodyPhoto {
        let taken = TestClock.date(date)
        return BodyPhoto(id: UUID(), pose: pose, takenAt: taken, createdAt: createdAt.map(TestClock.date) ?? taken)
    }

    private func weighing(_ date: String, _ kg: Double) -> BodyMeasurement {
        let day = TestClock.date(date)
        return BodyMeasurement(date: day, weightKg: kg, source: .manual, createdAt: day, updatedAt: day)
    }

    private func trend(_ measurements: [BodyMeasurement]) -> WeightTrend {
        WeightTrend.make(measurements: measurements, now: TestClock.date("2026-11-20T12:00"), calendar: calendar)
    }

    @Test func appleHealthSessionsTakeNoPhotos() {
        #expect(SessionPhotoRules.acceptsPhotos(session(.pulse)))
        #expect(SessionPhotoRules.acceptsPhotos(session(.hevy)))
        #expect(!SessionPhotoRules.acceptsPhotos(session(.appleHealth)))
    }

    @Test func remainingSlotsNeverNegative() {
        #expect(SessionPhotoRules.remainingSlots(current: 0) == 6)
        #expect(SessionPhotoRules.remainingSlots(current: 6) == 0)
        #expect(SessionPhotoRules.remainingSlots(current: 7) == 0)
    }

    @Test func daysGroupNewestFirst() {
        let front = photo(.front, "2026-11-01T08:00")
        let side = photo(.side, "2026-11-01T08:05")
        let later = photo(.front, "2026-11-15T19:00")
        let days = BodyPhotoTimeline.days([front, later, side], calendar: calendar)
        #expect(days.map(\.day) == [TestClock.date("2026-11-15T00:00"), TestClock.date("2026-11-01T00:00")])
        #expect(days[0].photos == [.front: later])
        #expect(days[1].photos == [.front: front, .side: side])
    }

    @Test func samePoseSameDayKeepsLatest() {
        let older = photo(.front, "2026-11-01T08:00", createdAt: "2026-11-01T08:00")
        let newer = photo(.front, "2026-11-01T20:00", createdAt: "2026-11-01T20:00")
        let days = BodyPhotoTimeline.days([newer, older], calendar: calendar)
        #expect(days.count == 1)
        #expect(days[0].photos == [.front: newer])
        #expect(BodyPhotoTimeline.existing(pose: .front, on: TestClock.date("2026-11-01T12:00"), in: [older, newer],
                                           calendar: calendar) == newer)
        #expect(BodyPhotoTimeline.existing(pose: .side, on: TestClock.date("2026-11-01T12:00"), in: [older, newer],
                                           calendar: calendar) == nil)
        #expect(BodyPhotoTimeline.existing(pose: .front, on: TestClock.date("2026-11-02T12:00"), in: [older, newer],
                                           calendar: calendar) == nil)
    }

    @Test func comparablePosesNeedTwoDays() {
        let photos = [photo(.front, "2026-11-01T08:00"), photo(.front, "2026-11-08T08:00"), photo(.back, "2026-11-01T08:00"),
                      photo(.back, "2026-11-01T21:00")]
        #expect(BodyPhotoTimeline.comparablePoses(photos, calendar: calendar) == [.front])
    }

    @Test func defaultPairIsOldestAndNewest() {
        let first = photo(.side, "2026-09-01T08:00")
        let middle = photo(.side, "2026-10-01T08:00")
        let last = photo(.side, "2026-11-01T08:00")
        let other = photo(.front, "2026-12-01T08:00")
        let pair = BodyPhotoTimeline.defaultPair(pose: .side, in: [middle, last, other, first], calendar: calendar)
        #expect(pair?.before == first)
        #expect(pair?.after == last)
        #expect(BodyPhotoTimeline.defaultPair(pose: .front, in: [other, middle], calendar: calendar) == nil)
    }

    @Test func weightChangeUsesTrendWithinSevenDays() throws {
        let weight = trend([weighing("2026-08-01T07:00", 70), weighing("2026-10-28T07:00", 68.6)])
        let change = BodyPhotoTimeline.weightChange(trend: weight, from: TestClock.date("2026-08-04T10:00"),
                                                    to: TestClock.date("2026-10-30T10:00"), calendar: calendar)
        #expect(try abs(#require(change) - -1.4) < 0.01)
    }

    @Test func weightChangeIsNilWithoutRecentTrend() {
        let weight = trend([weighing("2026-08-01T07:00", 70), weighing("2026-10-20T07:00", 68.6)])
        let change = BodyPhotoTimeline.weightChange(trend: weight, from: TestClock.date("2026-08-04T10:00"),
                                                    to: TestClock.date("2026-10-30T10:00"), calendar: calendar)
        #expect(change == nil)
    }
}
