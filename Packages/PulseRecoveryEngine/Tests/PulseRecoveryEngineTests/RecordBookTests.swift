import Foundation
import PulseDomain
@testable import PulseRecoveryEngine
import Testing

struct RecordBookTests {
    private let t0 = TestCalendar.day(2026, 11, 2)
    private let day1 = TestCalendar.day(2026, 10, 1)
    private let day2 = TestCalendar.day(2026, 10, 8)
    private let day3 = TestCalendar.day(2026, 10, 15)
    private let bench = ExerciseReference.content(id: "bench-press-barbell")
    private let dips = ExerciseReference.content(id: "dips-assisted")

    private func session(on date: Date, status: SessionStatus = .completed, exercise: ExerciseReference? = nil,
                         _ working: [(Double?, Int)], warmups: [(Double, Int)] = []) -> WorkoutSession {
        let exercise = exercise ?? bench
        let allSets = warmups.map { (SetType.warmup, Optional($0.0), $0.1) } + working.map { (SetType.working, $0.0, $0.1) }
        let sets = allSets.enumerated().map { index, entry in
            WorkoutSet(order: index, exercise: exercise, exerciseName: "Exercice", setType: entry.0,
                       actualWeightKg: entry.1, actualReps: entry.2)
        }
        return WorkoutSession(startedAt: date, kind: .strength, source: .pulse, status: status, title: "Séance",
                              sets: sets, createdAt: date, updatedAt: date)
    }

    private func session(on date: Date, bench sets: [(Double, Int)]) -> WorkoutSession {
        session(on: date, sets.map { (Optional($0.0), $0.1) })
    }

    private func compute(_ sessions: [WorkoutSession], kind: LoadKind = .external) -> RecordBook.Result {
        RecordBook.compute(sessions: sessions, loadKind: { _ in kind }, now: t0)
    }

    @Test func firstSessionSetsTheBaselineWithoutFlaggingSets() {
        let result = compute([session(on: day1, bench: [(60, 12), (70, 5)])])
        #expect(result.recordSetIDs.isEmpty)
        #expect(Set(result.records.map(\.kind)) == [.maxWeight, .estimatedOneRepMax])
        #expect(result.records.first { $0.kind == .maxWeight }?.value == 70)
        // 60 × 12 (86,4) estime plus haut que 70 × 5 (78,75).
        #expect(result.records.first { $0.kind == .estimatedOneRepMax }?.value == OneRepMax.brzycki(weightKg: 60, reps: 12))
        #expect(result.records.first { $0.kind == .estimatedOneRepMax }?.weightKg == 60)
    }

    @Test func heavierAndMoreRepsBeatTheirRecordsOncePerSession() {
        let result = compute([
            session(on: day1, bench: [(60, 12), (70, 5)]),
            session(on: day2, bench: [(60, 12), (72.5, 5), (70, 6), (70, 7)])
        ])
        let second = result.records.filter { $0.date == day2 }
        #expect(second.contains { $0.kind == .maxWeight && $0.value == 72.5 })
        #expect(second.filter { $0.kind == .repsAtWeight }.map(\.weightKg) == [70])
        #expect(second.first { $0.kind == .repsAtWeight }?.value == 7)
        #expect(!second.contains { $0.kind == .repsAtWeight && $0.weightKg == 72.5 })
        #expect(!result.recordSetIDs.isEmpty)
    }

    @Test func recordsCarryTheSessionContext() {
        let first = session(on: day1, bench: [(70, 5)])
        let second = session(on: day2, bench: [(72.5, 5)])
        let result = compute([second, first])
        let record = result.records.first { $0.kind == .maxWeight && $0.date == day2 }
        #expect(record?.sessionID == second.id)
        #expect(record?.setID == second.sets[0].id)
        #expect(record?.exercise == bench)
        #expect(record?.exerciseName == "Exercice")
        #expect(record?.createdAt == t0)
        #expect(record?.updatedAt == t0)
        #expect(result.recordSetIDs.contains(second.sets[0].id))
        #expect(!result.recordSetIDs.contains(first.sets[0].id))
    }

    @Test func assistedAndBodyweightOnlyTrackRepsAtWeight() {
        for kind in [LoadKind.assisted, .bodyweight] {
            let first = session(on: day1, exercise: dips, [(12.5, 10), (nil, 8)])
            let second = session(on: day2, exercise: dips, [(12.5, 12), (nil, 8), (15, 6)])
            let result = compute([first, second], kind: kind)
            #expect(result.records.allSatisfy { $0.kind == .repsAtWeight })
            #expect(result.records.map(\.date) == [day2])
            #expect(result.records.first?.weightKg == 12.5)
            #expect(result.records.first?.value == 12)
            #expect(result.recordSetIDs == [second.sets[0].id])
        }
    }

    @Test func bodyweightWithoutBallastComparesAtZero() {
        let result = compute([
            session(on: day1, exercise: dips, [(nil, 10)]),
            session(on: day2, exercise: dips, [(nil, 12)])
        ], kind: .bodyweight)
        #expect(result.records.map(\.weightKg) == [0])
        #expect(result.records.first?.value == 12)
    }

    @Test func warmupsAndAbandonedSessionsFollowTheRules() {
        let first = session(on: day1, bench: [(60, 10)])
        let second = session(on: day2, status: .abandoned, [(62.5, 8)], warmups: [(100, 3)])
        let inProgress = session(on: day3, status: .inProgress, [(200, 5)])
        let result = compute([first, second, inProgress])
        let maxWeights = result.records.filter { $0.kind == .maxWeight }
        #expect(maxWeights.map(\.value) == [60, 62.5])
        #expect(maxWeights.map(\.date) == [day1, day2])
    }

    @Test func equalValuesAreNotRecords() {
        let result = compute([
            session(on: day1, bench: [(70, 5)]),
            session(on: day2, bench: [(70, 5)])
        ])
        #expect(result.records.allSatisfy { $0.date == day1 })
        #expect(result.recordSetIDs.isEmpty)
    }

    @Test func setsWithoutRepsOrBeyond12RepsAreHandled() {
        let result = compute([
            session(on: day1, bench: [(60, 0), (50, 15)])
        ])
        #expect(result.records.map(\.kind) == [.maxWeight])
        #expect(result.records.first?.value == 50)
    }

    @Test func exercisesAreTrackedIndependently() {
        let first = session(on: day1, bench: [(70, 5)])
        let other = session(on: day2, exercise: dips, [(80, 5)])
        let result = compute([first, other])
        let dipsRecords = result.records.filter { $0.exercise == dips }
        #expect(Set(dipsRecords.map(\.kind)) == [.maxWeight, .estimatedOneRepMax])
        #expect(result.recordSetIDs.isEmpty)
    }
}
