import Foundation
@testable import NightFeature
import PulseDomain
import PulseServices
import Testing

@MainActor
struct NightModelTests {
    private let now = NightFixtures.date(2026, 11, 20, 9, 0)

    /// Un modèle sur les nuits qui se réveillent les jours donnés de novembre 2026.
    private func model(wakingOn days: [Int], initialDay: Date?) async throws -> NightModel {
        let cache = InMemoryHealthSampleCache()
        try await cache.insert(days.flatMap { NightFixtures.samples(wakingOn: 2026, 11, $0, now: now) })
        let now = now
        let service = NightDetailService(cache: cache, calendar: NightFixtures.calendar, now: { now })
        let model = NightModel(service: service, initialDay: initialDay, calendar: NightFixtures.calendar)
        await model.load()
        return model
    }

    @Test func opensOnTheRequestedNight() async throws {
        let model = try await model(wakingOn: [17, 18, 19], initialDay: NightFixtures.date(2026, 11, 18, 14, 0))
        #expect(model.current?.night.day == NightFixtures.date(2026, 11, 18))
    }

    @Test func opensOnTheLatestNightWhenTheDayHasNone() async throws {
        let model = try await model(wakingOn: [17, 18], initialDay: NightFixtures.date(2026, 11, 20, 9, 0))
        #expect(model.current?.night.day == NightFixtures.date(2026, 11, 18))
    }

    @Test func backAndForwardStopAtTheEnds() async throws {
        let model = try await model(wakingOn: [10, 18], initialDay: NightFixtures.date(2026, 11, 10))
        #expect(model.canGoBack == false && model.canGoForward)
        model.goBack()
        #expect(model.current?.night.day == NightFixtures.date(2026, 11, 10))
        model.goForward()
        #expect(model.current?.night.day == NightFixtures.date(2026, 11, 18), "les nuits vides entre les deux sont sautées")
        #expect(model.canGoForward == false && model.canGoBack)
        model.goForward()
        #expect(model.current?.night.day == NightFixtures.date(2026, 11, 18))
    }

    @Test func emptyServiceLeavesNoCurrentNight() async throws {
        let model = try await model(wakingOn: [], initialDay: now)
        #expect(model.hasLoaded)
        #expect(model.current == nil)
        #expect(model.canGoBack == false && model.canGoForward == false)
    }

    @Test func loadReadsTheGoal() async throws {
        let profiles = InMemoryProfileRepository()
        try await profiles.save(UserProfile(sleepGoalMinutes: 420, createdAt: now, updatedAt: now))
        let now = now
        let service = NightDetailService(cache: InMemoryHealthSampleCache(), profiles: profiles, calendar: NightFixtures.calendar,
                                         now: { now })
        let model = NightModel(service: service, initialDay: nil, calendar: NightFixtures.calendar)
        #expect(model.goalMinutes == SleepGoal.defaultMinutes)
        await model.load()
        #expect(model.goalMinutes == 420)
    }
}
