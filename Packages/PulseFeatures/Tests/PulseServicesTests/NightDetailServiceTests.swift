import Foundation
import PulseDomain
import PulseServices
import Testing

struct NightDetailServiceTests {
    private let calendar = TestClock.calendar
    private let now = TestClock.date("2026-11-20T09:00")

    /// Une nuit qui finit le matin du jour `wake` : 23 h → 7 h, avec `deep` minutes de profond à partir de 1 h.
    private func night(wakingOn wake: String, deep: Int = 90, staged: Bool = true) -> [CachedHealthSample] {
        let wakeDay = TestClock.date("\(wake)T00:00")
        let bedtime = calendar.date(byAdding: .hour, value: -1, to: wakeDay) ?? wakeDay
        let deepStart = calendar.date(byAdding: .hour, value: 1, to: wakeDay) ?? wakeDay
        let deepEnd = deepStart.addingTimeInterval(Double(deep) * 60)
        let wakeUp = calendar.date(byAdding: .hour, value: 7, to: wakeDay) ?? wakeDay
        func sample(_ start: Date, _ end: Date, _ stage: SleepStage) -> CachedHealthSample {
            CachedHealthSample(kind: .sleep, start: start, end: end, sleepStage: stage, fetchedAt: now)
        }
        guard staged else { return [sample(bedtime, wakeUp, .asleepUnspecified)] }
        return [sample(bedtime, deepStart, .core), sample(deepStart, deepEnd, .deep), sample(deepEnd, wakeUp, .core)]
    }

    private func service(_ samples: [CachedHealthSample]) async throws -> NightDetailService {
        let cache = InMemoryHealthSampleCache()
        try await cache.insert(samples)
        let now = now
        return NightDetailService(cache: cache, calendar: calendar, now: { now })
    }

    @Test func nightsSkipDaysWithoutSleep() async throws {
        let nights = try await service(night(wakingOn: "2026-11-17") + night(wakingOn: "2026-11-19")).nights()
        #expect(nights.map(\.night.day) == [TestClock.date("2026-11-17T00:00"), TestClock.date("2026-11-19T00:00")])
    }

    @Test func nightsAreChronological() async throws {
        let nights = try await service(night(wakingOn: "2026-11-19") + night(wakingOn: "2026-11-10")).nights()
        #expect(nights.map(\.night.day) == [TestClock.date("2026-11-10T00:00"), TestClock.date("2026-11-19T00:00")])
    }

    @Test func averagesUseUpToFourteenPreviousStagedNights() async throws {
        let earlier = (3...18).flatMap { night(wakingOn: String(format: "2026-11-%02d", $0)) }
        let nights = try await service(earlier + night(wakingOn: "2026-11-19", deep: 60)).nights()
        let last = try #require(nights.last)
        #expect(last.night.deepMinutes == 60)
        #expect(last.averages?.deep == 90)
        #expect(last.averages?.nights == 14)
    }

    @Test func firstNightHasNoAverages() async throws {
        let nights = try await service(night(wakingOn: "2026-11-18") + night(wakingOn: "2026-11-19")).nights()
        #expect(nights.first?.averages == nil)
        #expect(nights.last?.averages?.nights == 1)
    }

    @Test func unstagedNightHasNoAverages() async throws {
        let nights = try await service(night(wakingOn: "2026-11-18") + night(wakingOn: "2026-11-19", staged: false)).nights()
        #expect(nights.last?.night.hasStages == false)
        #expect(nights.last?.averages == nil)
    }

    @Test func emptyCacheGivesNoNights() async throws {
        #expect(try await service([]).nights().isEmpty)
    }
}
