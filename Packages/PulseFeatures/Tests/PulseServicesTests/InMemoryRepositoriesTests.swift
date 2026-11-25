import Foundation
import PulseDomain
import PulseServices
import Testing

struct InMemoryRepositoriesTests {
    private let day = TestClock.date("2026-11-02T00:00")

    private func recovery(score: Double, at date: Date, createdAt: Date) -> DailyRecovery {
        DailyRecovery(day: date, score: score, category: .optimal, isEstimated: false, calibration: .ready,
                      createdAt: createdAt, updatedAt: createdAt)
    }

    @Test func recoverySaveKeepsOneRecordPerLocalDay() async throws {
        let repository = InMemoryRecoveryRepository(calendar: TestClock.calendar)
        let first = recovery(score: 60, at: TestClock.date("2026-11-02T08:30"), createdAt: day)
        let second = recovery(score: 80, at: TestClock.date("2026-11-02T21:00"), createdAt: TestClock.date("2026-11-03T00:00"))
        try await repository.save(first)
        try await repository.save(second)
        let stored = try await repository.dailyRecoveries(from: day, to: TestClock.date("2026-11-03T00:00"))
        #expect(stored.count == 1)
        #expect(stored.first?.day == day && stored.first?.score == 80)
        #expect(stored.first?.id == first.id && stored.first?.createdAt == day)
    }

    @Test func profileLoadReturnsTheOldestAndDeleteIsLogical() async throws {
        let repository = InMemoryProfileRepository()
        let older = UserProfile(createdAt: day, updatedAt: day)
        let newer = UserProfile(createdAt: TestClock.date("2026-11-03T00:00"), updatedAt: day)
        try await repository.save(newer)
        try await repository.save(older)
        #expect(try await repository.load()?.id == older.id)
        try await repository.delete(id: older.id)
        #expect(try await repository.load()?.id == newer.id)
    }

    @Test func profileUpdateKeepsOtherFieldsAndSkipsUnchanged() async throws {
        let repository = InMemoryProfileRepository()
        #expect(try await repository.update { $0.weightKg = 75 } == nil)
        try await repository.save(UserProfile(firstName: "Mathéo", createdAt: day, updatedAt: day))
        let later = TestClock.date("2026-11-03T00:00")
        let changed = try #require(try await repository.update { profile in
            profile.weightKg = 75
            profile.updatedAt = later
        })
        #expect(changed.didChange && changed.after.firstName == "Mathéo" && changed.after.weightKg == 75)
        let unchanged = try #require(try await repository.update { $0.weightKg = 75 })
        #expect(!unchanged.didChange)
        #expect(try await repository.load() == changed.after)
    }

    @Test func bodyMeasurementsAreSoftDeleted() async throws {
        func measurement(_ text: String, _ weight: Double) -> BodyMeasurement {
            BodyMeasurement(date: TestClock.date(text), weightKg: weight, source: .manual, createdAt: day, updatedAt: day)
        }
        let early = measurement("2026-11-02T08:00", 78)
        let middle = measurement("2026-11-03T08:00", 77.5)
        let late = measurement("2026-11-04T08:00", 77)
        let repository = InMemoryBodyMeasurementRepository([late, early])
        try await repository.save(middle)

        // `from` inclus, `to` exclu, trié par date.
        let all = try await repository.measurements(from: early.date, to: late.date)
        #expect(all.map(\.id) == [early.id, middle.id])
        try await repository.delete(id: early.id)
        #expect(try await repository.measurements(from: .distantPast, to: .distantFuture).map(\.id) == [middle.id, late.id])
    }

    @Test func programListingsExcludeDeletedAndArchived() async throws {
        let repository = InMemoryProgramRepository()
        let active = Program(name: "A", sessionsPerWeek: 3, weekLayout: [], days: [], createdAt: day, updatedAt: day)
        let archived = Program(name: "B", sessionsPerWeek: 3, weekLayout: [], isArchived: true, days: [], createdAt: day, updatedAt: day)
        let removed = Program(name: "C", sessionsPerWeek: 3, weekLayout: [], days: [], createdAt: day, updatedAt: day)
        for program in [active, archived, removed] { try await repository.save(program) }
        try await repository.delete(id: removed.id)
        #expect(try await repository.programs(includeArchived: false).map(\.id) == [active.id])
        #expect(try await repository.programs(includeArchived: true).count == 2)
        #expect(try await repository.program(id: removed.id) == nil)
        var renamed = active
        renamed.name = "A2"
        try await repository.save(renamed)
        #expect(try await repository.program(id: active.id)?.name == "A2")
    }
}

private func anchoredSample(_ kind: HealthSampleKind = .sdnn, uuid: String?, at offset: TimeInterval = 0) -> CachedHealthSample {
    let start = Date(timeIntervalSince1970: 1_794_700_000 + offset)
    return CachedHealthSample(kind: kind, start: start, end: start.addingTimeInterval(60), value: 50, healthKitUUID: uuid, fetchedAt: start)
}

private func allSamples(_ cache: InMemoryHealthSampleCache, _ kind: HealthSampleKind) async throws -> [CachedHealthSample] {
    try await cache.samples(kind: kind, from: .distantPast, to: .distantFuture)
}

@Test func fullReadReplacesTheKind() async throws {
    let cache = InMemoryHealthSampleCache()
    let sleep = anchoredSample(.sleep, uuid: "S")
    try await cache.insert([anchoredSample(uuid: nil), anchoredSample(uuid: nil, at: 60), sleep])
    let added = anchoredSample(uuid: "A", at: 120)
    try await cache.apply(HealthSampleChanges(kind: .sdnn, added: [added], deletedHealthKitUUIDs: [],
                                              anchor: Data([7]), isFullRead: true))
    #expect(try await allSamples(cache, .sdnn) == [added])
    #expect(try await allSamples(cache, .sleep) == [sleep])
    #expect(try await cache.anchor(for: .sdnn) == Data([7]))
}

@Test func applyingPrunesSamplesBeyondTheRetentionOfTheKind() async throws {
    let cache = InMemoryHealthSampleCache()
    let oldSleep = anchoredSample(.sleep, uuid: "SLEEP", at: -90 * 86_400)
    try await cache.insert([anchoredSample(uuid: "OLD", at: -63 * 86_400), anchoredSample(uuid: "KEPT", at: -61 * 86_400), oldSleep])
    try await cache.apply(HealthSampleChanges(kind: .sdnn, added: [anchoredSample(uuid: "NEW")], deletedHealthKitUUIDs: [],
                                              anchor: Data([1]), isFullRead: false))
    #expect(try await allSamples(cache, .sdnn).map(\.healthKitUUID) == ["KEPT", "NEW"])
    #expect(try await allSamples(cache, .sleep) == [oldSleep])
}

@Test func runSamplesAreKeptForAYear() async throws {
    let cache = InMemoryHealthSampleCache()
    try await cache.insert([anchoredSample(.run, uuid: "RUN", at: -300 * 86_400), anchoredSample(uuid: "OLD", at: -70 * 86_400)])
    try await cache.apply(HealthSampleChanges(kind: .run, added: [anchoredSample(.run, uuid: "NEW")], deletedHealthKitUUIDs: [],
                                              anchor: Data([1]), isFullRead: false))
    try await cache.apply(HealthSampleChanges(kind: .sdnn, added: [anchoredSample(uuid: "NEW")], deletedHealthKitUUIDs: [],
                                              anchor: Data([1]), isFullRead: false))
    #expect(try await allSamples(cache, .run).map(\.healthKitUUID) == ["RUN", "NEW"])
    #expect(try await allSamples(cache, .sdnn).map(\.healthKitUUID) == ["NEW"])
}

@Test func incrementalReadRemovesDeleted() async throws {
    let cache = InMemoryHealthSampleCache()
    let first = anchoredSample(uuid: "A")
    let second = anchoredSample(uuid: "B", at: 60)
    try await cache.insert([first, second])
    try await cache.apply(HealthSampleChanges(kind: .sdnn, added: [], deletedHealthKitUUIDs: ["A"],
                                              anchor: Data([1]), isFullRead: false))
    #expect(try await allSamples(cache, .sdnn) == [second])
}

@Test func returningSampleIsNotDuplicated() async throws {
    let cache = InMemoryHealthSampleCache()
    let sample = anchoredSample(uuid: "A")
    try await cache.insert([sample])
    try await cache.apply(HealthSampleChanges(kind: .sdnn, added: [sample], deletedHealthKitUUIDs: [],
                                              anchor: Data([1]), isFullRead: false))
    #expect(try await allSamples(cache, .sdnn) == [sample])
}

@Test func anchorIsKeptPerKind() async throws {
    let cache = InMemoryHealthSampleCache()
    try await cache.apply(HealthSampleChanges(kind: .sdnn, added: [anchoredSample(uuid: "A")], deletedHealthKitUUIDs: [],
                                              anchor: Data([1]), isFullRead: false))
    #expect(try await cache.anchor(for: .sleep) == nil)
    #expect(try await cache.anchor(for: .sdnn) == Data([1]))
}

@Test func workoutSessionsAreFilteredByStartAndSorted() async throws {
    let repository = InMemoryWorkoutRepository()
    func session(_ text: String) -> WorkoutSession {
        let start = TestClock.date(text)
        return WorkoutSession(startedAt: start, kind: .strength, source: .pulse, status: .completed, title: text,
                              createdAt: start, updatedAt: start)
    }
    let late = session("2026-11-02T18:00")
    let early = session("2026-11-01T08:00")
    let outside = session("2026-11-03T00:00")
    for item in [late, outside, early] { try await repository.save(item) }
    let found = try await repository.sessions(from: TestClock.date("2026-11-01T08:00"), to: TestClock.date("2026-11-03T00:00"))
    #expect(found.map(\.id) == [early.id, late.id])
    try await repository.delete(id: early.id)
    #expect(try await repository.session(id: early.id) == nil)
}
