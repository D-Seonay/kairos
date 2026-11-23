import Foundation
import PulseDomain
@testable import PulseServices
import Testing

struct RunDuplicatesTests {
    private func run(_ source: SessionSource, from start: String, to end: String, kind: SessionKind = .run, heartRate: Double? = nil,
                     estimatedRPE: Double? = nil) -> WorkoutSession {
        let startedAt = TestClock.date(start)
        return WorkoutSession(startedAt: startedAt, endedAt: TestClock.date(end), kind: kind, source: source, status: .completed,
                              title: "Course", durationMinutes: TestClock.date(end).timeIntervalSince(startedAt) / 60,
                              averageHeartRate: heartRate, estimatedRPE: estimatedRPE, createdAt: startedAt, updatedAt: startedAt)
    }

    @Test func fullOverlapHidesTheWatchRun() {
        let pulse = run(.pulse, from: "2026-11-20T07:00", to: "2026-11-20T07:30")
        let watch = run(.appleHealth, from: "2026-11-20T07:01", to: "2026-11-20T07:31")
        #expect(RunDuplicates.resolve([pulse, watch]).map(\.id) == [pulse.id])
    }

    @Test func fortyPercentOverlapKeepsBoth() {
        let pulse = run(.pulse, from: "2026-11-20T07:00", to: "2026-11-20T07:30")
        let watch = run(.appleHealth, from: "2026-11-20T07:18", to: "2026-11-20T07:48")
        #expect(RunDuplicates.resolve([pulse, watch]).count == 2)
    }

    @Test func exactlyHalfOverlapHidesTheWatchRun() {
        let pulse = run(.pulse, from: "2026-11-20T07:00", to: "2026-11-20T07:30")
        let watch = run(.appleHealth, from: "2026-11-20T07:15", to: "2026-11-20T07:45")
        #expect(RunDuplicates.resolve([pulse, watch]).map(\.id) == [pulse.id])
    }

    @Test func splitWatchRunIsHiddenTwice() {
        let pulse = run(.pulse, from: "2026-11-20T07:00", to: "2026-11-20T07:30")
        let first = run(.appleHealth, from: "2026-11-20T07:00", to: "2026-11-20T07:14")
        let second = run(.appleHealth, from: "2026-11-20T07:16", to: "2026-11-20T07:30")
        #expect(RunDuplicates.resolve([first, pulse, second]).map(\.id) == [pulse.id])
    }

    @Test func duplicateEstimatedRPEFillsThePulseRun() throws {
        let pulse = run(.pulse, from: "2026-11-20T07:00", to: "2026-11-20T07:30")
        let watch = run(.appleHealth, from: "2026-11-20T07:01", to: "2026-11-20T07:31", heartRate: 160, estimatedRPE: 8)
        let shown = try #require(RunDuplicates.resolve([pulse, watch]).first)
        #expect(shown.estimatedRPE == 8 && shown.averageHeartRate == 160)
        #expect(TrainingLoad.loadSession(shown)?.rpe == 8)
    }

    @Test func pulseRunOwnHeartRateWins() throws {
        let pulse = run(.pulse, from: "2026-11-20T07:00", to: "2026-11-20T07:30", heartRate: 150)
        let watch = run(.appleHealth, from: "2026-11-20T07:01", to: "2026-11-20T07:31", heartRate: 160, estimatedRPE: 8)
        let shown = try #require(RunDuplicates.resolve([pulse, watch]).first)
        #expect(shown.averageHeartRate == 150)
    }

    @Test func deletedPulseRunBringsTheWatchRunBack() {
        let watch = run(.appleHealth, from: "2026-11-20T07:01", to: "2026-11-20T07:31")
        #expect(RunDuplicates.resolve([watch]).map(\.id) == [watch.id])
    }

    @Test func ridesAreNeverMerged() {
        let pulse = run(.pulse, from: "2026-11-20T07:00", to: "2026-11-20T07:30")
        let ride = run(.appleHealth, from: "2026-11-20T07:01", to: "2026-11-20T07:31", kind: .ride)
        #expect(RunDuplicates.resolve([pulse, ride]).count == 2)
    }

    @Test func aSessionWithoutDurationNeverMatches() {
        let pulse = run(.pulse, from: "2026-11-20T07:00", to: "2026-11-20T07:30")
        var watch = run(.appleHealth, from: "2026-11-20T07:10", to: "2026-11-20T07:10")
        watch.endedAt = nil
        watch.durationMinutes = nil
        #expect(RunDuplicates.resolve([pulse, watch]).count == 2)
    }

    @Test func decoratorHidesDuplicatesOverADayEitherSide() async throws {
        let base = InMemoryWorkoutRepository()
        let pulse = run(.pulse, from: "2026-11-20T23:50", to: "2026-11-21T00:20")
        let watch = run(.appleHealth, from: "2026-11-21T00:00", to: "2026-11-21T00:20")
        try await base.save(pulse)
        try await base.save(watch)
        let repository = DeduplicatingWorkoutRepository(base: base)
        // La course montre commence le 21 mais son doublon Pulse commence le 20 : la fenêtre élargie le voit.
        let day = TestClock.date("2026-11-21T00:00")
        #expect(try await repository.sessions(from: day, to: day.addingTimeInterval(86_400)).isEmpty)
        #expect(try await repository.sessions(from: .distantPast, to: .distantFuture).map(\.id) == [pulse.id])
    }

    @Test func decoratorSaveNeverCopiesTheDuplicateIntoStorage() async throws {
        let base = InMemoryWorkoutRepository()
        let pulse = run(.pulse, from: "2026-11-20T07:00", to: "2026-11-20T07:30")
        let watch = run(.appleHealth, from: "2026-11-20T07:01", to: "2026-11-20T07:31", heartRate: 160, estimatedRPE: 8)
        try await base.save(pulse)
        try await base.save(watch)
        let repository = DeduplicatingWorkoutRepository(base: base)

        var shown = try #require(try await repository.sessions(from: .distantPast, to: .distantFuture).first { $0.id == pulse.id })
        #expect(shown.averageHeartRate == 160)
        shown.overallRPE = 7
        try await repository.save(shown)

        let stored = try #require(try await base.session(id: pulse.id))
        #expect(stored.overallRPE == 7)
        #expect(stored.averageHeartRate == nil && stored.estimatedRPE == nil)
    }

    @Test func aBrandNewPulseRunKeepsItsLiveHeartRate() async throws {
        let base = InMemoryWorkoutRepository()
        let repository = DeduplicatingWorkoutRepository(base: base)
        let pulse = run(.pulse, from: "2026-11-20T07:00", to: "2026-11-20T07:30", heartRate: 148, estimatedRPE: 6)
        try await repository.save(pulse)
        #expect(try await base.session(id: pulse.id) == pulse)
    }

    @Test func otherSessionsPassThroughSave() async throws {
        let base = InMemoryWorkoutRepository()
        let repository = DeduplicatingWorkoutRepository(base: base)
        let watch = run(.appleHealth, from: "2026-11-20T07:00", to: "2026-11-20T07:30", heartRate: 150, estimatedRPE: 7)
        try await repository.save(watch)
        #expect(try await base.session(id: watch.id) == watch)
    }

    @Test func detailLookupShowsTheBorrowedHeartRate() async throws {
        let base = InMemoryWorkoutRepository()
        let pulse = run(.pulse, from: "2026-11-20T07:00", to: "2026-11-20T07:30")
        let watch = run(.appleHealth, from: "2026-11-20T07:01", to: "2026-11-20T07:31", heartRate: 160, estimatedRPE: 8)
        try await base.save(pulse)
        try await base.save(watch)
        let repository = DeduplicatingWorkoutRepository(base: base)
        #expect(try await repository.session(id: pulse.id)?.averageHeartRate == 160)
        #expect(try await repository.session(id: watch.id)?.id == watch.id)
        #expect(try await repository.session(id: UUID()) == nil)
    }
}
