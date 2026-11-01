import Foundation
import PulseDomain
import PulseRecoveryEngine
import PulseServices
import Testing

struct ScenarioTests {
    @Test(arguments: HealthScenario.allCases)
    func scenarioOutcome(_ scenario: HealthScenario) async throws {
        let now = TestClock.date("2026-11-02T08:00")
        let source = ScenarioHealthSource(scenario: scenario, now: now, calendar: TestClock.calendar)
        let history = NightHistory(source: source, cache: InMemoryHealthSampleCache(), calendar: TestClock.calendar)
        let snapshot = await history.refresh(now: now)
        let outcome = RecoveryCalculator(calendar: TestClock.calendar)
            .compute(day: TestClock.calendar.startOfDay(for: now), today: try #require(snapshot.nights.last),
                     history: snapshot.nights.dropLast())
        switch scenario {
        case .goodNight: #expect(outcome.measured?.category == .optimal && outcome.measured?.calibration == .ready)
        case .badNight: #expect(outcome.measured?.category == .moderateFatigue)
        case .missingHRV: #expect(outcome.measured?.missing == [.hrv])
        case .threeNights, .noData: #expect(outcome.isCheckIn)
        }
    }

    @Test func profileHintsFollowTheScenario() async throws {
        let now = TestClock.date("2026-11-02T08:00")
        let hints = try await ScenarioHealthSource(scenario: .goodNight, now: now, calendar: TestClock.calendar).profileHints()
        #expect(hints.sex == .male && hints.heightCm == 178 && hints.weightKg == 74.5)
        let birth = try #require(hints.birthDate)
        #expect(TestClock.calendar.dateComponents([.year, .month, .day], from: birth) == DateComponents(year: 1998, month: 3, day: 14))
        let empty = try await ScenarioHealthSource(scenario: .noData, now: now, calendar: TestClock.calendar).profileHints()
        #expect(empty == HealthProfileHints())
    }

    @Test func failingSourceThrowsEverywhere() async {
        let source = FailingHealthSource()
        let now = TestClock.date("2026-11-02T08:00")
        await #expect(throws: FailingHealthSource.Failure.unavailable) { try await source.requestAuthorization() }
        await #expect(throws: FailingHealthSource.Failure.unavailable) { try await source.sdnnSamples(from: now, to: now) }
        await #expect(throws: FailingHealthSource.Failure.unavailable) { try await source.restingHeartRateSamples(from: now, to: now) }
        await #expect(throws: FailingHealthSource.Failure.unavailable) { try await source.sleepIntervals(from: now, to: now) }
        await #expect(throws: FailingHealthSource.Failure.unavailable) { try await source.profileHints() }
    }
}
