import Foundation
import PulseDomain
@testable import PulseServices
import Testing

/// Une source d'entraînements qui rend, par type, la réponse préparée ; `nil` : la lecture échoue.
private actor ScriptedWorkoutSource: HealthWorkoutSource {
    struct Failure: Error {}

    var runs: [CachedHealthSample]? = []
    var rides: [CachedHealthSample]? = []
    var deleted: [String] = []

    func set(runs: [CachedHealthSample]?, deleted: [String] = []) {
        self.runs = runs
        self.deleted = deleted
    }

    func workoutChanges(of signal: WorkoutSignal, since anchor: Data?, from start: Date) async throws -> HealthSampleChanges {
        guard let added = signal == .run ? runs : rides else { throw Failure() }
        return HealthSampleChanges(kind: signal.kind, added: added, deletedHealthKitUUIDs: signal == .run ? deleted : [],
                                   anchor: Data("a".utf8), isFullRead: anchor == nil)
    }
}

struct WorkoutHistoryTests {
    private let source = ScriptedWorkoutSource()
    private let cache = InMemoryHealthSampleCache()
    private let workouts = InMemoryWorkoutRepository()
    private let profiles = InMemoryProfileRepository()
    private let now = TestClock.date("2026-11-20T12:00")

    private var history: WorkoutHistory {
        WorkoutHistory(source: source, cache: cache, workouts: workouts, profiles: profiles, calendar: TestClock.calendar)
    }

    private func run(_ uuid: String, at text: String, heartRate: Double? = 150) -> CachedHealthSample {
        let start = TestClock.date(text)
        return CachedHealthSample(kind: .run, start: start, end: start.addingTimeInterval(45 * 60), distanceMeters: 8_200,
                                  averageHeartRate: heartRate, durationMinutes: 45, healthKitUUID: uuid, fetchedAt: start)
    }

    private func imported() async throws -> [WorkoutSession] {
        try await workouts.sessions(from: .distantPast, to: .distantFuture)
    }

    @Test func newRunsBecomeAppleHealthSessions() async throws {
        try await profiles.save(UserProfile(birthDate: TestClock.date("1996-11-20T00:00")))
        await source.set(runs: [run("r1", at: "2026-11-17T07:30")])

        #expect(await history.refresh(now: now))
        let sessions = try await imported()
        #expect(sessions.count == 1)
        let session = try #require(sessions.first)
        #expect(session.source == .appleHealth && session.kind == .run && session.status == .completed)
        #expect(session.title == "Course" && session.durationMinutes == 45 && session.distanceMeters == 8_200)
        #expect(session.healthKitUUID == "r1")
        // 150 / 187 = 0,80 → 7.
        #expect(session.estimatedRPE == 7)
    }

    @Test func aSecondPassChangesNothingAndKeepsWhatWasTypedInPulse() async throws {
        await source.set(runs: [run("r1", at: "2026-11-17T07:30")])
        await history.refresh(now: now)
        var session = try #require(try await imported().first)
        session.overallRPE = 8
        session.note = "Jambes lourdes"
        try await workouts.save(session)

        await source.set(runs: [])
        #expect(await !history.refresh(now: now))
        let kept = try #require(try await imported().first)
        #expect(kept.overallRPE == 8 && kept.note == "Jambes lourdes" && kept.id == session.id)
    }

    @Test func aRunDeletedInHealthRemovesItsSession() async throws {
        await source.set(runs: [run("r1", at: "2026-11-17T07:30"), run("r2", at: "2026-11-18T07:30")])
        await history.refresh(now: now)
        await source.set(runs: [], deleted: ["r1"])

        #expect(await history.refresh(now: now))
        #expect(try await imported().map(\.healthKitUUID) == ["r2"])
    }

    @Test func aFailedReadKeepsSessions() async throws {
        await source.set(runs: [run("r1", at: "2026-11-17T07:30")])
        await history.refresh(now: now)
        await source.set(runs: nil)

        #expect(await !history.refresh(now: now))
        #expect(try await imported().count == 1)
    }

    @Test func pulseSessionsAndOldImportsAreNeverTouched() async throws {
        let strength = PlanningFixtures.session("2026-11-17T18:00")
        var old = PlanningFixtures.session("2026-08-01T07:00", kind: .run, source: .appleHealth)
        old.healthKitUUID = "old"
        try await workouts.save(strength)
        try await workouts.save(old)
        await source.set(runs: [])

        await history.refresh(now: now)
        #expect(try await imported().count == 2)
    }

    @Test func runWithoutHeartRateHasNoEstimatedRPE() {
        let session = WorkoutHistory.session(from: run("r1", at: "2026-11-17T07:30", heartRate: nil), signal: .run, existing: nil,
                                             maxHeartRate: 190, now: now)
        #expect(session.estimatedRPE == nil)
    }
}
