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

    @Test func unavailableSourceThrowsEverywhere() async {
        let source = UnavailableHealthSource()
        let now = TestClock.date("2026-11-02T08:00")
        await #expect(throws: UnavailableHealthSource.Failure.unavailable) { try await source.requestAuthorization() }
        for signal in NightSignal.allCases {
            await #expect(throws: UnavailableHealthSource.Failure.unavailable) {
                try await source.changes(of: signal, since: nil, from: now)
            }
        }
        await #expect(throws: UnavailableHealthSource.Failure.unavailable) { try await source.profileHints() }
    }

    @Test func scenarioSendsEverythingThenNothing() async throws {
        let now = TestClock.date("2026-11-02T08:00")
        let start = TestClock.date("2026-09-03T00:00")
        let source = ScenarioHealthSource(scenario: .goodNight, now: now, calendar: TestClock.calendar)
        let first = try await source.changes(of: .sdnn, since: nil, from: start)
        #expect(first.isFullRead && first.kind == .sdnn)
        #expect(first.added.count == 180)
        #expect(first.added.allSatisfy { $0.kind == .sdnn && $0.value != nil })
        #expect(first.deletedHealthKitUUIDs.isEmpty)
        let uuids = first.added.compactMap(\.healthKitUUID)
        #expect(Set(uuids).count == 180 && uuids.allSatisfy { $0.hasPrefix("scenario.sdnn.") })
        #expect(first.anchor == Data("2026-11-02".utf8))
        let second = try await source.changes(of: .sdnn, since: first.anchor, from: start)
        #expect(second.added.isEmpty && second.deletedHealthKitUUIDs.isEmpty)
        #expect(second.isFullRead == false)
        #expect(second.anchor == first.anchor)
    }

    @Test func scenarioResendsEverythingForAnotherDay() async throws {
        let now = TestClock.date("2026-11-02T08:00")
        let start = TestClock.date("2026-09-03T00:00")
        let source = ScenarioHealthSource(scenario: .goodNight, now: now, calendar: TestClock.calendar)
        let changes = try await source.changes(of: .sleep, since: Data("2026-11-01".utf8), from: start)
        #expect(changes.isFullRead)
        #expect(changes.kind == .sleep)
        #expect(changes.added.isEmpty == false)
        #expect(changes.added.allSatisfy { $0.sleepStage != nil && $0.start >= start })
        #expect(changes.anchor == Data("2026-11-02".utf8))
    }
}
