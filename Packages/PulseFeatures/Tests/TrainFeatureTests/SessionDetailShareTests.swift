import Foundation
import PulseDesignSystem
import PulseDomain
import PulseServices
import Testing
@testable import TrainFeature

private let bench = ExerciseReference.content(id: "bench-press-barbell")

@MainActor @Test func detailShareCardShowsTheStrengthSessionAndItsRecords() async throws {
    let fixture = TrainFixture()
    try await fixture.log(on: TrainClock.date(month: 10, day: 5, hour: 18), sets: [LoggedSet(weightKg: 60, reps: 5)])
    let date = TrainClock.date(month: 10, day: 12, hour: 18)
    let session = WorkoutSession(
        startedAt: date, endedAt: date.addingTimeInterval(3_900), kind: .strength, source: .pulse, status: .completed, title: "Push",
        sets: [WorkoutSet(order: 0, exercise: bench, exerciseName: "Développé couché", setType: .working, actualWeightKg: 80,
                          actualReps: 5, completedAt: date)],
        createdAt: date, updatedAt: date)
    try await fixture.environment.workouts.save(session)
    _ = try await fixture.environment.records.recomputeAll()
    let model = SessionDetailModel(environment: fixture.environment, sessionID: session.id)
    #expect(model.shareContent == nil)

    await model.load()
    let card = try #require(model.shareContent)
    #expect(card.eyebrow == "Séance")
    #expect(card.title == "Push")
    #expect(card.subtitle == "lundi 12 octobre")
    #expect(card.metrics.map(\.label) == ["Durée", "kg soulevés", "Séries", "Records"])
    #expect(card.metrics.map(\.value) == ["1 h 05", "400", "1", "1"])
    #expect(card.highlights.count == 1)
    #expect(card.highlights.first?.hasSuffix(": 80 × 5") == true)
    #expect(card.visual == .muscles(model.muscleLevels))
}

@MainActor @Test func enduranceShareCardGivesPaceForARunAndSpeedForARide() {
    let date = TrainClock.date(month: 10, day: 12, hour: 8)
    func session(_ kind: SessionKind) -> WorkoutSession {
        WorkoutSession(startedAt: date, endedAt: date.addingTimeInterval(1_800), kind: kind, source: .appleHealth, status: .completed,
                       title: "", durationMinutes: 30, distanceMeters: 6_000, createdAt: date, updatedAt: date)
    }
    let run = SessionDetailModel.enduranceShareContent(of: session(.run), day: "lundi 12 octobre")
    #expect(run.eyebrow == "Course")
    #expect(run.title == "Course")
    #expect(run.metrics.map(\.value) == ["6 km", "30 min", "5'00\"/km"])
    let ride = SessionDetailModel.enduranceShareContent(of: session(.ride), day: "lundi 12 octobre")
    #expect(ride.eyebrow == "Vélo")
    #expect(ride.metrics.last?.value == "12 km/h")
}
