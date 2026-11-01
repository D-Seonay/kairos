import Foundation
import PulseDomain
import PulseServices
import Testing

struct DailyScoreServiceTests {
    private var calendar: Calendar { TestClock.calendar }

    private struct Fixture {
        let repository: InMemoryRecoveryRepository
        let service: DailyScoreService
    }

    private func fixture() -> Fixture {
        let repository = InMemoryRecoveryRepository(calendar: TestClock.calendar)
        return Fixture(repository: repository, service: DailyScoreService(recovery: repository, calendar: TestClock.calendar))
    }

    private func nights(_ scenario: HealthScenario, at now: Date) async -> [NightSample] {
        let source = ScenarioHealthSource(scenario: scenario, now: now, calendar: calendar)
        let history = NightHistory(source: source, cache: InMemoryHealthSampleCache(), calendar: calendar)
        return await history.refresh(now: now).nights
    }

    private func records(_ fixture: Fixture, on text: String) async throws -> [DailyRecovery] {
        let day = TestClock.date(text)
        return try await fixture.repository.dailyRecoveries(from: day, to: calendar.date(byAdding: .day, value: 1, to: day) ?? day)
    }

    private func scored(_ score: TodayScore) throws -> DailyRecovery {
        guard case .scored(let recovery) = score else {
            throw Failure.notScored(score)
        }
        return recovery
    }

    private enum Failure: Error { case notScored(TodayScore) }

    private func yesterday() -> DailyRecovery {
        DailyRecovery(day: TestClock.date("2026-11-01T00:00"), score: 70, category: .normal, isEstimated: false,
                      calibration: .ready, frozenAt: TestClock.date("2026-11-01T12:00"),
                      createdAt: TestClock.date("2026-11-01T08:00"), updatedAt: TestClock.date("2026-11-01T12:00"))
    }

    @Test func before4amReturnsYesterday() async throws {
        let fixture = fixture()
        let previous = yesterday()
        try await fixture.repository.save(previous)
        let now = TestClock.date("2026-11-02T03:59")
        let result = try await fixture.service.update(nights: await nights(.goodNight, at: now), now: now)
        #expect(result == .beforeDayStart(yesterday: previous))
        #expect(try await records(fixture, on: "2026-11-02T00:00").isEmpty)
    }

    @Test func before4amWithoutYesterdayReturnsNil() async throws {
        let fixture = fixture()
        let now = TestClock.date("2026-11-02T01:00")
        let result = try await fixture.service.update(nights: await nights(.goodNight, at: now), now: now)
        #expect(result == .beforeDayStart(yesterday: nil))
    }

    @Test func morningMeasuredScoreIsSaved() async throws {
        let fixture = fixture()
        let now = TestClock.date("2026-11-02T08:00")
        let recovery = try scored(try await fixture.service.update(nights: await nights(.goodNight, at: now), now: now))
        #expect(recovery.category == .optimal)
        #expect(recovery.isEstimated == false)
        #expect(recovery.frozenAt == nil)
        #expect(recovery.day == TestClock.date("2026-11-02T00:00"))
        #expect(try await records(fixture, on: "2026-11-02T00:00").count == 1)
    }

    @Test func newDataBeforeNoonRecomputes() async throws {
        let fixture = fixture()
        let early = TestClock.date("2026-11-02T07:00")
        let first = try scored(try await fixture.service.update(nights: await nights(.badNight, at: early), now: early))
        #expect(first.category == .moderateFatigue)
        let later = TestClock.date("2026-11-02T09:00")
        let second = try scored(try await fixture.service.update(nights: await nights(.goodNight, at: later), now: later))
        #expect(second.category == .optimal)
        let stored = try await records(fixture, on: "2026-11-02T00:00")
        #expect(stored.count == 1 && stored.first?.category == .optimal)
    }

    @Test func measuredReplacesCheckInBeforeNoon() async throws {
        let fixture = fixture()
        let early = TestClock.date("2026-11-02T07:00")
        let estimated = try await fixture.service.saveCheckIn(CheckInAnswers(sleep: 3, pain: 3, motivation: 3), now: early)
        #expect(estimated.isEstimated)
        let later = TestClock.date("2026-11-02T08:00")
        let measured = try scored(try await fixture.service.update(nights: await nights(.goodNight, at: later), now: later))
        #expect(measured.isEstimated == false)
        #expect(try await records(fixture, on: "2026-11-02T00:00").first?.isEstimated == false)
    }

    @Test func noonFreezesTheExistingScore() async throws {
        let fixture = fixture()
        let morning = TestClock.date("2026-11-02T08:00")
        _ = try await fixture.service.update(nights: await nights(.badNight, at: morning), now: morning)
        let noon = TestClock.date("2026-11-02T12:00")
        let frozen = try scored(try await fixture.service.update(nights: await nights(.goodNight, at: noon), now: noon))
        #expect(frozen.category == .moderateFatigue)
        #expect(frozen.frozenAt == noon)
        let again = TestClock.date("2026-11-02T15:00")
        let unchanged = try scored(try await fixture.service.update(nights: await nights(.goodNight, at: again), now: again))
        #expect(unchanged.category == .moderateFatigue)
        #expect(unchanged.frozenAt == noon)
    }

    @Test func afterNoonWithoutScoreSavesAFrozenMeasure() async throws {
        let fixture = fixture()
        let now = TestClock.date("2026-11-02T14:00")
        let recovery = try scored(try await fixture.service.update(nights: await nights(.goodNight, at: now), now: now))
        #expect(recovery.frozenAt == now)
        #expect(recovery.category == .optimal)
    }

    @Test func afterNoonCheckInStaysOpenThenFreezes() async throws {
        let fixture = fixture()
        let now = TestClock.date("2026-11-02T14:00")
        let result = try await fixture.service.update(nights: await nights(.threeNights, at: now), now: now)
        #expect(result == .needsCheckIn(missing: [.hrv, .restingHeartRate]))
        let estimated = try await fixture.service.saveCheckIn(CheckInAnswers(sleep: 2, pain: 2, motivation: 2), now: now)
        #expect(estimated.frozenAt == now)
        #expect(estimated.isEstimated)
    }

    @Test func checkInSavesAnEstimatedRecoveryAndTheCheckIn() async throws {
        let fixture = fixture()
        let now = TestClock.date("2026-11-02T08:00")
        let answers = CheckInAnswers(sleep: 4, pain: 2, motivation: 0)
        let recovery = try await fixture.service.saveCheckIn(answers, now: now)
        let expected: Double = 100 * 0.40 + 50 * 0.35
        #expect(recovery.score == expected)
        #expect(recovery.isEstimated && recovery.frozenAt == nil)
        #expect(recovery.missingFactors == Factor.allCases)
        #expect(recovery.calibration == .calibrating(nights: 0))
        let day = TestClock.date("2026-11-02T00:00")
        let checkIns = try await fixture.repository.checkIns(from: day, to: TestClock.date("2026-11-03T00:00"))
        #expect(checkIns.count == 1 && checkIns.first?.answers == answers && checkIns.first?.score == recovery.score)
    }

    @Test func frozenDayRejectsCheckIn() async throws {
        let fixture = fixture()
        let noon = TestClock.date("2026-11-02T12:00")
        _ = try await fixture.service.update(nights: await nights(.goodNight, at: noon), now: noon)
        await #expect(throws: DailyScoreError.frozen) {
            try await fixture.service.saveCheckIn(CheckInAnswers(sleep: 1, pain: 1, motivation: 1), now: noon)
        }
    }

    @Test func insufficientDataNeedsCheckIn() async throws {
        let fixture = fixture()
        let now = TestClock.date("2026-11-02T08:00")
        let result = try await fixture.service.update(nights: await nights(.noData, at: now), now: now)
        #expect(result == .needsCheckIn(missing: [.hrv, .restingHeartRate, .sleep]))
        #expect(try await records(fixture, on: "2026-11-02T00:00").isEmpty)
    }

    @Test func existingCheckInIsKeptWhileDataStaysInsufficient() async throws {
        let fixture = fixture()
        let early = TestClock.date("2026-11-02T07:00")
        let estimated = try await fixture.service.saveCheckIn(CheckInAnswers(sleep: 3, pain: 3, motivation: 3), now: early)
        let later = TestClock.date("2026-11-02T09:00")
        let result = try await fixture.service.update(nights: await nights(.noData, at: later), now: later)
        #expect(result == .scored(estimated))
    }

    @Test func measuredRecoveryCarriesRawValues() async throws {
        let fixture = fixture()
        let now = TestClock.date("2026-11-02T08:00")
        let recovery = try scored(try await fixture.service.update(nights: await nights(.goodNight, at: now), now: now))
        #expect(recovery.sdnnMs == 56)
        #expect(recovery.restingHeartRate == 48)
        #expect(recovery.asleepMinutes == 480)
        #expect(recovery.deepMinutes == 96)
        #expect(recovery.sdnnBaselineMs != nil)
        #expect(recovery.restingHeartRateBaseline != nil)
        #expect(recovery.hrvScore != nil && recovery.restingHeartRateScore != nil && recovery.sleepScore != nil)
        #expect(recovery.calibration == .ready)
        #expect(recovery.missingFactors.isEmpty && recovery.adjustments.isEmpty)
    }

    @Test func dayStartAndFreezeFollowTheCalendarOnDSTDay() async throws {
        let fixture = fixture()
        let dayStart = TestClock.date("2026-10-25T00:00")
        let early = TestClock.date("2026-10-25T03:59")
        let before = try await fixture.service.update(nights: await nights(.goodNight, at: early), now: early)
        #expect(before == .beforeDayStart(yesterday: nil))
        let start = TestClock.date("2026-10-25T04:00")
        let measured = try scored(try await fixture.service.update(nights: await nights(.goodNight, at: start), now: start))
        #expect(measured.day == dayStart && measured.frozenAt == nil)
        let noon = TestClock.date("2026-10-25T12:00")
        let frozen = try scored(try await fixture.service.update(nights: await nights(.goodNight, at: noon), now: noon))
        #expect(frozen.day == dayStart && frozen.frozenAt == noon)
    }

    @Test(arguments: ["2026-11-02", "2026-10-25"])
    func freezeHappensAtNoonSharpNotBefore(day: String) async throws {
        let fixture = fixture()
        let beforeNoon = TestClock.date("\(day)T11:59")
        let open = try scored(try await fixture.service.update(nights: await nights(.goodNight, at: beforeNoon), now: beforeNoon))
        #expect(open.frozenAt == nil)
        #expect(try await records(fixture, on: "\(day)T00:00").first?.frozenAt == nil)
        let noon = TestClock.date("\(day)T12:00")
        let frozen = try scored(try await fixture.service.update(nights: await nights(.goodNight, at: noon), now: noon))
        #expect(frozen.frozenAt == noon)
        #expect(try await records(fixture, on: "\(day)T00:00").first?.frozenAt == noon)
    }
}
