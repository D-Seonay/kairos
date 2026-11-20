import Foundation
import PulseDomain
import PulseServices
import Testing

struct SessionCorrectionTests {
    private let now = TestClock.date("2026-11-20T12:00")

    private func session() -> WorkoutSession {
        let start = TestClock.date("2026-11-18T18:00")
        let bench = ExerciseReference.content(id: "bench-press")
        let sets = [
            WorkoutSet(order: 0, exercise: bench, exerciseName: "Développé couché", setType: .warmup, actualWeightKg: 40, actualReps: 10),
            WorkoutSet(order: 1, exercise: bench, exerciseName: "Développé couché", setType: .working, actualWeightKg: 80, actualReps: 5),
            WorkoutSet(order: 2, exercise: bench, exerciseName: "Développé couché", setType: .working, actualWeightKg: 80, actualReps: 4)
        ]
        return WorkoutSession(startedAt: start, endedAt: start.addingTimeInterval(3_600), kind: .strength, source: .pulse,
                              status: .completed, title: "Push", tonnageKg: 720, sets: sets, createdAt: start, updatedAt: start)
    }

    @Test func startsFromTheWorkingSets() {
        let correction = SessionCorrection(session: session())
        #expect(correction.sets.count == 2 && correction.note.isEmpty && correction.overallRPE == nil)
    }

    @Test func appliesSetsNoteAndRPEAndRecomputesTonnage() throws {
        let original = session()
        var correction = SessionCorrection(session: original)
        correction.sets[1].reps = 5
        correction.sets[1].rpe = 9
        correction.note = "  Bonne séance \n"
        correction.overallRPE = 8

        let corrected = correction.applied(to: original, loadKind: { _ in .external }, now: now)
        #expect(corrected.sets.count == 3)
        #expect(corrected.sets[2].actualReps == 5 && corrected.sets[2].rpe == 9)
        #expect(corrected.note == "Bonne séance" && corrected.overallRPE == 8)
        #expect(corrected.tonnageKg == 800 && corrected.updatedAt == now)
        #expect(corrected.startedAt == original.startedAt)
    }

    @Test func removesSetsAndClearsZeroValues() throws {
        let original = session()
        var correction = SessionCorrection(session: original)
        correction.removedSetIDs = [original.sets[2].id]
        correction.sets[0].weightKg = 0

        let corrected = correction.applied(to: original, loadKind: { _ in .external }, now: now)
        #expect(corrected.sets.map(\.order) == [0, 1])
        #expect(corrected.sets[1].actualWeightKg == nil && corrected.tonnageKg == 0)
    }

    @Test func unchangedSessionKeepsItsDate() {
        let original = session()
        let corrected = SessionCorrection(session: original).applied(to: original, loadKind: { _ in .external }, now: now)
        #expect(corrected.updatedAt == original.updatedAt)
    }
}
