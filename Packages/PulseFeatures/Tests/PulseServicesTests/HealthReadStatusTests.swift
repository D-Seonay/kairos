import Foundation
import PulseDomain
import PulseServices
import Testing

struct HealthReadStatusTests {
    private func sample(_ kind: HealthSampleKind, start: String, end: String? = nil, fetched: String) -> CachedHealthSample {
        CachedHealthSample(kind: kind, start: TestClock.date(start), end: TestClock.date(end ?? start), value: 1,
                           fetchedAt: TestClock.date(fetched))
    }

    @Test func latestPerKindAndLastRead() async throws {
        let cache = InMemoryHealthSampleCache()
        try await cache.insert([
            sample(.sdnn, start: "2026-11-19T07:00", fetched: "2026-11-20T08:00"),
            sample(.sdnn, start: "2026-11-18T07:00", fetched: "2026-11-20T08:00"),
            sample(.run, start: "2026-11-01T09:00", end: "2026-11-01T10:00", fetched: "2026-11-20T09:30")
        ])

        let status = try await HealthReadStatus.read(cache: cache)

        #expect(status.kinds.map(\.kind) == HealthSampleKind.allCases)
        #expect(status.kinds.first { $0.kind == .sdnn }?.latest == TestClock.date("2026-11-19T07:00"))
        #expect(status.kinds.first { $0.kind == .run }?.latest == TestClock.date("2026-11-01T09:00"))
        #expect(status.kinds.filter { $0.latest == nil }.count == HealthSampleKind.allCases.count - 2)
        #expect(status.lastRead == TestClock.date("2026-11-20T09:30"))
    }

    @Test func sleepUsesTheWakeUpTime() async throws {
        let cache = InMemoryHealthSampleCache()
        try await cache.insert([sample(.sleep, start: "2026-11-19T23:00", end: "2026-11-20T07:00", fetched: "2026-11-20T08:00")])

        let status = try await HealthReadStatus.read(cache: cache)

        #expect(status.kinds.first { $0.kind == .sleep }?.latest == TestClock.date("2026-11-20T07:00"))
    }

    @Test func emptyCacheHasNoData() async throws {
        let status = try await HealthReadStatus.read(cache: InMemoryHealthSampleCache())

        #expect(status.lastRead == nil)
        #expect(status.kinds.allSatisfy { $0.latest == nil })
    }
}
