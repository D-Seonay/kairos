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

    /// Une nuit endormie sans phase, de `bedtime` (HH:mm, la veille avant minuit, ou le jour même après) jusqu'à 07:00 le jour `wake`.
    private func night(wakingOn wake: String, fellAsleep bedtime: Date) -> CachedHealthSample {
        let wakeUp = TestClock.date("\(wake)T07:00")
        return CachedHealthSample(kind: .sleep, start: bedtime, end: wakeUp, sleepStage: .asleepUnspecified, fetchedAt: now)
    }

    @Test func regularityCoversTheFourteenDaysEndingAtEachNight() async throws {
        let bedtimes = ["2026-11-13T23:00", "2026-11-14T23:30", "2026-11-16T00:00", "2026-11-16T23:30", "2026-11-17T23:30",
                        "2026-11-18T23:30"]
        let wakes = ["2026-11-14", "2026-11-15", "2026-11-16", "2026-11-17", "2026-11-18", "2026-11-19"]
        let samples = zip(wakes, bedtimes).map { night(wakingOn: $0, fellAsleep: TestClock.date($1)) }
        let nights = try await service(samples).nights()
        #expect(nights.count == 6)
        #expect(nights.last?.bedtimeRegularityMinutes == 10)
    }

    @Test func regularityNeedsFiveNights() async throws {
        let samples = (14...19).map { night(wakingOn: String(format: "2026-11-%02d", $0)) }.flatMap { $0 }
        let nights = try await service(samples).nights()
        #expect(nights.prefix(4).allSatisfy { $0.bedtimeRegularityMinutes == nil })
        #expect(nights[4].bedtimeRegularityMinutes == 0)
    }

    @Test func regularityIgnoresNightsOlderThanFourteenDays() async throws {
        // Quatre nuits à 23:00 puis, quinze jours plus tard, une à 23:00 : la fenêtre de la dernière n'a plus que cette nuit.
        let samples = (2...5).flatMap { night(wakingOn: String(format: "2026-11-%02d", $0)) }
            + night(wakingOn: "2026-11-19")
        let nights = try await service(samples).nights()
        #expect(nights.count == 5)
        #expect(nights.last?.bedtimeRegularityMinutes == nil)
    }

    @Test func sleepGoalComesFromTheProfile() async throws {
        let profiles = InMemoryProfileRepository()
        try await profiles.save(UserProfile(sleepGoalMinutes: 420, createdAt: now, updatedAt: now))
        let now = now
        let cache = InMemoryHealthSampleCache()
        func service(_ profiles: (any ProfileRepository)?) -> NightDetailService {
            NightDetailService(cache: cache, profiles: profiles, calendar: calendar, now: { now })
        }
        #expect(await service(profiles).sleepGoalMinutes() == 420)
        #expect(await service(nil).sleepGoalMinutes() == 480)
        #expect(await service(UnreadableProfiles()).sleepGoalMinutes() == 480)
    }
}

/// Un dépôt de profils dont la lecture lève toujours.
private struct UnreadableProfiles: ProfileRepository {
    private struct Failure: Error {}

    func load() async throws -> UserProfile? { throw Failure() }

    func save(_ profile: UserProfile) async throws { throw Failure() }

    func delete(id: UUID) async throws { throw Failure() }

    func update(_ transform: @Sendable (inout UserProfile) throws -> Void) async throws -> ProfileUpdate? { throw Failure() }
}
