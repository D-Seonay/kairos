import Foundation
import PulseDomain
import PulseServices
import Synchronization
import Testing

struct NightHistoryTests {
    private struct Boom: Error {}

    private let now = TestClock.date("2026-11-02T08:00")
    /// Aujourd'hui moins 60 jours : le début de la lecture.
    private let historyStart = TestClock.date("2026-09-03T00:00")
    private var calendar: Calendar { TestClock.calendar }

    private func scenarioSource(_ scenario: HealthScenario = .goodNight) -> ScenarioHealthSource {
        ScenarioHealthSource(scenario: scenario, now: now, calendar: calendar)
    }

    private func history(_ scenario: HealthScenario, cache: InMemoryHealthSampleCache) -> NightHistory {
        NightHistory(source: scenarioSource(scenario), cache: cache, calendar: calendar)
    }

    /// La première lecture complète du scénario, signal par signal.
    private func fullReads(_ source: ScenarioHealthSource) async throws -> [NightSignal: HealthSampleChanges] {
        var reads: [NightSignal: HealthSampleChanges] = [:]
        for signal in NightSignal.allCases {
            reads[signal] = try await source.changes(of: signal, since: nil, from: historyStart)
        }
        return reads
    }

    private func unchanged(_ signal: NightSignal, anchor: Data) -> HealthSampleChanges {
        HealthSampleChanges(kind: signal.kind, added: [], deletedHealthKitUUIDs: [], anchor: anchor, isFullRead: false)
    }

    @Test func refreshReturnsSixtyNightsEndingToday() async {
        let snapshot = await history(.goodNight, cache: InMemoryHealthSampleCache()).refresh(now: now)
        #expect(snapshot.nights.count == 60)
        #expect(snapshot.nights.last?.day == TestClock.date("2026-11-02T00:00"))
        #expect(snapshot.nights.first?.day == TestClock.date("2026-09-04T00:00"))
        #expect(snapshot.readAt == now)
        #expect(snapshot.nights.allSatisfy { $0.sleep?.asleepMinutes == 480 && $0.sleep?.deepMinutes == 96 })
    }

    @Test func firstRefreshReadsSixtyDaysAndStoresAnchors() async throws {
        let cache = InMemoryHealthSampleCache()
        let snapshot = await history(.goodNight, cache: cache).refresh(now: now)
        #expect(snapshot.nights.count == 60)
        #expect(snapshot.readAt == now)
        for signal in NightSignal.allCases {
            #expect(try await cache.anchor(for: signal.kind) != nil)
        }
    }

    @Test func refreshDoesNotDuplicateTheCache() async throws {
        let cache = InMemoryHealthSampleCache()
        let from = TestClock.date("2026-08-01T00:00")
        let to = TestClock.date("2026-11-04T00:00")
        _ = await history(.goodNight, cache: cache).refresh(now: now)
        let first = try await cache.samples(kind: .sdnn, from: from, to: to).count
        _ = await history(.goodNight, cache: cache).refresh(now: now)
        let second = try await cache.samples(kind: .sdnn, from: from, to: to).count
        #expect(first > 0 && first == second)
        #expect(try await cache.samples(kind: .sleep, from: from, to: to).isEmpty == false)
        #expect(try await cache.samples(kind: .restingHeartRate, from: from, to: to).isEmpty == false)
    }

    @Test func secondRefreshOnlyAsksForChanges() async throws {
        let full = try await fullReads(scenarioSource())
        let script = ScriptedHealthSource()
        for signal in NightSignal.allCases {
            await script.enqueue(.success(try #require(full[signal])), for: signal)
            await script.enqueue(.success(unchanged(signal, anchor: Data([9]))), for: signal)
        }
        let cache = InMemoryHealthSampleCache()
        let nightHistory = NightHistory(source: script, cache: cache, calendar: calendar)
        let first = await nightHistory.refresh(now: now)
        let second = await nightHistory.refresh(now: now)
        for signal in NightSignal.allCases {
            #expect(await script.receivedAnchors(for: signal) == [nil, full[signal]?.anchor])
            #expect(try await cache.anchor(for: signal.kind) == Data([9]))
        }
        #expect(first.nights.count == 60)
        #expect(second.nights == first.nights)
        #expect(second.readAt == now)
    }

    @Test func deletedSampleLeavesTheNights() async throws {
        let full = try await fullReads(scenarioSource())
        let todayStart = calendar.startOfDay(for: now)
        let todays = try #require(full[.sdnn]).added.filter { $0.start >= todayStart }.compactMap(\.healthKitUUID)
        #expect(todays.count == 3)
        let script = ScriptedHealthSource()
        for signal in NightSignal.allCases {
            await script.enqueue(.success(try #require(full[signal])), for: signal)
        }
        await script.enqueue(.success(HealthSampleChanges(kind: .sdnn, added: [], deletedHealthKitUUIDs: todays,
                                                          anchor: Data([9]), isFullRead: false)), for: .sdnn)
        await script.enqueue(.success(unchanged(.restingHeartRate, anchor: Data([9]))), for: .restingHeartRate)
        await script.enqueue(.success(unchanged(.sleep, anchor: Data([9]))), for: .sleep)
        let nightHistory = NightHistory(source: script, cache: InMemoryHealthSampleCache(), calendar: calendar)
        let first = await nightHistory.refresh(now: now)
        let second = await nightHistory.refresh(now: now)
        #expect(first.nights.last?.sdnnMs == 56)
        #expect(second.nights.last?.sdnnMs == nil)
        #expect(second.nights.dropLast() == first.nights.dropLast())
    }

    @Test func m3aCacheIsReplacedOnFirstAnchoredRead() async throws {
        let source = scenarioSource()
        let from = TestClock.date("2026-08-01T00:00")
        let to = TestClock.date("2026-11-04T00:00")
        var legacy: [CachedHealthSample] = []
        for (_, read) in try await fullReads(source) {
            legacy += read.added.map { sample in
                var plain = sample
                plain.healthKitUUID = nil
                return plain
            }
        }
        let migrated = InMemoryHealthSampleCache()
        try await migrated.insert(legacy)
        let after = await NightHistory(source: source, cache: migrated, calendar: calendar).refresh(now: now)
        let reference = InMemoryHealthSampleCache()
        let fresh = await NightHistory(source: source, cache: reference, calendar: calendar).refresh(now: now)
        #expect(after.nights == fresh.nights)
        for kind in [HealthSampleKind.sdnn, .restingHeartRate, .sleep] {
            let migratedCount = try await migrated.samples(kind: kind, from: from, to: to).count
            let referenceCount = try await reference.samples(kind: kind, from: from, to: to).count
            #expect(migratedCount > 0)
            #expect(migratedCount == referenceCount)
        }
    }

    @Test func failingSignalKeepsItsAnchorAndCache() async throws {
        let full = try await fullReads(scenarioSource())
        let script = ScriptedHealthSource()
        for signal in NightSignal.allCases {
            await script.enqueue(.success(try #require(full[signal])), for: signal)
        }
        await script.enqueue(.success(unchanged(.sdnn, anchor: Data([9]))), for: .sdnn)
        await script.enqueue(.success(unchanged(.restingHeartRate, anchor: Data([9]))), for: .restingHeartRate)
        await script.enqueue(.failure(Boom()), for: .sleep)
        let cache = InMemoryHealthSampleCache()
        let nightHistory = NightHistory(source: script, cache: cache, calendar: calendar)
        _ = await nightHistory.refresh(now: now)
        let second = await nightHistory.refresh(now: now)
        #expect(second.readAt == nil)
        #expect(try await cache.anchor(for: .sleep) == full[.sleep]?.anchor)
        #expect(try await cache.anchor(for: .sdnn) == Data([9]))
        #expect(second.nights.last?.sleep?.asleepMinutes == 480)
        #expect(second.nights.last?.sdnnMs == 56)
    }

    @Test func unavailableSourceFallsBackToCache() async throws {
        let cache = InMemoryHealthSampleCache()
        _ = await history(.goodNight, cache: cache).refresh(now: now)
        let fallback = await NightHistory(source: UnavailableHealthSource(), cache: cache, calendar: calendar).refresh(now: now)
        #expect(fallback.readAt == nil)
        #expect(fallback.nights.count == 60)
        #expect(fallback.nights.last?.sdnnMs == 56)
        #expect(fallback.nights.last?.sleep?.asleepMinutes == 480)
    }

    @Test func unavailableSourceLeavesTheCacheIntact() async throws {
        let cache = InMemoryHealthSampleCache()
        _ = await history(.goodNight, cache: cache).refresh(now: now)
        let from = TestClock.date("2026-08-01T00:00")
        let to = TestClock.date("2026-11-04T00:00")
        let before = try await cache.samples(kind: .sdnn, from: from, to: to)
        let anchor = try await cache.anchor(for: .sdnn)
        _ = await NightHistory(source: UnavailableHealthSource(), cache: cache, calendar: calendar).refresh(now: now)
        #expect(try await cache.samples(kind: .sdnn, from: from, to: to) == before)
        #expect(try await cache.anchor(for: .sdnn) == anchor)
    }

    @Test func progressEndsAtOne() async {
        let values = Mutex<[Double]>([])
        _ = await history(.goodNight, cache: InMemoryHealthSampleCache()).refresh(now: now) { value in
            values.withLock { $0.append(value) }
        }
        #expect(values.withLock { $0 } == [0.25, 0.5, 0.75, 1])
    }
}
