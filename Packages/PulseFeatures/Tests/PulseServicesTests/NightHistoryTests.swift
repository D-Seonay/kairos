import Foundation
import PulseDomain
import PulseServices
import Synchronization
import Testing

struct NightHistoryTests {
    private let now = TestClock.date("2026-11-02T08:00")
    private var calendar: Calendar { TestClock.calendar }

    private func history(_ scenario: HealthScenario, cache: InMemoryHealthSampleCache) -> NightHistory {
        NightHistory(source: ScenarioHealthSource(scenario: scenario, now: now, calendar: calendar), cache: cache, calendar: calendar)
    }

    @Test func refreshReturnsSixtyNightsEndingToday() async {
        let snapshot = await history(.goodNight, cache: InMemoryHealthSampleCache()).refresh(now: now)
        #expect(snapshot.nights.count == 60)
        #expect(snapshot.nights.last?.day == TestClock.date("2026-11-02T00:00"))
        #expect(snapshot.nights.first?.day == TestClock.date("2026-09-04T00:00"))
        #expect(snapshot.readAt == now)
        #expect(snapshot.nights.allSatisfy { $0.sleep?.asleepMinutes == 480 && $0.sleep?.deepMinutes == 96 })
    }

    @Test func refreshReplacesTheCache() async throws {
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

    @Test func failedReadFallsBackToCache() async throws {
        let cache = InMemoryHealthSampleCache()
        _ = await history(.goodNight, cache: cache).refresh(now: now)
        let fallback = await NightHistory(source: FailingHealthSource(), cache: cache, calendar: calendar).refresh(now: now)
        #expect(fallback.readAt == nil)
        #expect(fallback.nights.count == 60)
        #expect(fallback.nights.last?.sdnnMs == 56)
        #expect(fallback.nights.last?.sleep?.asleepMinutes == 480)
    }

    @Test func failedReadLeavesTheCacheIntact() async throws {
        let cache = InMemoryHealthSampleCache()
        _ = await history(.goodNight, cache: cache).refresh(now: now)
        let from = TestClock.date("2026-08-01T00:00")
        let to = TestClock.date("2026-11-04T00:00")
        let before = try await cache.samples(kind: .sdnn, from: from, to: to)
        _ = await NightHistory(source: FailingHealthSource(), cache: cache, calendar: calendar).refresh(now: now)
        #expect(try await cache.samples(kind: .sdnn, from: from, to: to) == before)
    }

    @Test func progressEndsAtOne() async {
        let values = Mutex<[Double]>([])
        _ = await history(.goodNight, cache: InMemoryHealthSampleCache()).refresh(now: now) { value in
            values.withLock { $0.append(value) }
        }
        #expect(values.withLock { $0 } == [0.25, 0.5, 0.75, 1])
    }
}
