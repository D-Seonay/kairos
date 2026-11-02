import Foundation
import PulseDomain
import PulseServices
import Testing

/// Le score du jour et la séance prévue : ajustements enregistrés, choix « Séance d'origine », check-in refusé une fois mesuré,
/// opérations sérialisées.
struct DailyScoreSessionTests: DailyScoreTesting {
    @Test func measuredScoreStoresTheDaysAdjustments() async throws {
        let fixture = fixture()
        let now = TestClock.date("2026-11-02T08:00")
        let monday = try plannedDay(at: now)
        let recovery = try scored(try await fixture.service.update(nights: await nights(.badNight, at: now), plannedDay: monday, now: now))
        #expect(recovery.category == .moderateFatigue)
        #expect(recovery.adjustments.map(\.kind) == [.volume, .rpeCap, .rest])
        #expect(try await records(fixture, on: "2026-11-02T00:00").first?.adjustments == recovery.adjustments)
    }

    @Test func restDayStoresNoAdjustment() async throws {
        let fixture = fixture()
        let now = TestClock.date("2026-11-03T08:00")
        let tuesday = try plannedDay(at: now)
        let recovery = try scored(try await fixture.service.update(nights: await nights(.badNight, at: now), plannedDay: tuesday, now: now))
        #expect(recovery.category == .moderateFatigue)
        #expect(recovery.adjustments.isEmpty)
    }

    @Test func recomputeKeepsTheOriginalSessionChoice() async throws {
        let fixture = fixture()
        let early = TestClock.date("2026-11-02T07:00")
        let monday = try plannedDay(at: early)
        _ = try await fixture.service.update(nights: await nights(.badNight, at: early), plannedDay: monday, now: early)
        _ = try await fixture.service.chooseOriginalSession(true, now: TestClock.date("2026-11-02T07:30"))
        let later = TestClock.date("2026-11-02T09:00")
        let recomputed = try scored(try await fixture.service.update(nights: await nights(.goodNight, at: later), plannedDay: monday,
                                                                     now: later))
        #expect(recomputed.category == .optimal)
        #expect(recomputed.originalSessionChosen == true)
        #expect(try await records(fixture, on: "2026-11-02T00:00").first?.originalSessionChosen == true)
    }

    @Test func checkInIsRefusedOnceMeasured() async throws {
        let fixture = fixture()
        let now = TestClock.date("2026-11-02T08:00")
        let measured = try scored(try await fixture.service.update(nights: await nights(.goodNight, at: now), now: now))
        await #expect(throws: DailyScoreError.alreadyMeasured) {
            try await fixture.service.saveCheckIn(CheckInAnswers(sleep: 1, pain: 1, motivation: 1),
                                                  now: TestClock.date("2026-11-02T09:00"))
        }
        #expect(try await records(fixture, on: "2026-11-02T00:00") == [measured])
        let day = TestClock.date("2026-11-02T00:00")
        #expect(try await fixture.repository.checkIns(from: day, to: TestClock.date("2026-11-03T00:00")).isEmpty)
    }

    @Test func checkInStoresAdjustments() async throws {
        let fixture = fixture()
        let now = TestClock.date("2026-11-02T08:00")
        let monday = try plannedDay(at: now)
        let result = try await fixture.service.update(nights: await nights(.threeNights, at: now), plannedDay: monday, now: now)
        guard case .needsCheckIn = result else { throw DailyScoreTestFailure.notScored(result) }
        let answers = CheckInAnswers(sleep: 1, pain: 1, motivation: 1)
        let estimated = try await fixture.service.saveCheckIn(answers, plannedDay: monday, now: now)
        #expect(estimated.isEstimated)
        #expect(!estimated.adjustments.isEmpty)
        #expect(try await records(fixture, on: "2026-11-02T00:00").first?.adjustments == estimated.adjustments)
    }

    @Test func originalSessionCanBeChosenAfterNoon() async throws {
        let fixture = fixture()
        let morning = TestClock.date("2026-11-02T08:00")
        let monday = try plannedDay(at: morning)
        _ = try await fixture.service.update(nights: await nights(.badNight, at: morning), plannedDay: monday, now: morning)
        let afterNoon = TestClock.date("2026-11-02T12:30")
        let frozen = try scored(try await fixture.service.update(nights: await nights(.badNight, at: afterNoon), plannedDay: monday,
                                                                  now: afterNoon))
        let chosen = try await fixture.service.chooseOriginalSession(true, now: TestClock.date("2026-11-02T18:00"))
        #expect(chosen.originalSessionChosen == true)
        #expect(chosen.score == frozen.score && chosen.category == frozen.category && chosen.adjustments == frozen.adjustments)
        #expect(chosen.frozenAt == afterNoon)
        #expect(try await records(fixture, on: "2026-11-02T00:00") == [chosen])
        let adjusted = try await fixture.service.chooseOriginalSession(false, now: TestClock.date("2026-11-02T19:00"))
        #expect(adjusted.originalSessionChosen == false && adjusted.frozenAt == afterNoon)
    }

    @Test func choosingWithoutScoreThrows() async throws {
        let fixture = fixture()
        let now = TestClock.date("2026-11-02T08:00")
        _ = try await fixture.service.update(nights: await nights(.noData, at: now), now: now)
        await #expect(throws: DailyScoreError.noScoreToday) {
            try await fixture.service.chooseOriginalSession(true, now: now)
        }
    }

    @Test func updateAndCheckInAreSerialised() async throws {
        let repository = CountingRecoveryRepository(calendar: calendar)
        let service = DailyScoreService(recovery: repository, calendar: calendar)
        let gate = Gate()
        await repository.holdRecoverySaves(at: gate)
        let now = TestClock.date("2026-11-02T08:00")
        let nights = await nights(.goodNight, at: now)
        let update = Task { try await service.update(nights: nights, now: now) }
        await gate.waitForArrival()
        let calls = await repository.calls
        let checkIn = Task { try await service.saveCheckIn(CheckInAnswers(sleep: 1, pain: 1, motivation: 1), now: now) }
        for _ in 0..<100 { await Task.yield() }
        #expect(await repository.calls == calls)

        await gate.open()
        _ = try scored(try await update.value)
        await #expect(throws: DailyScoreError.alreadyMeasured) { try await checkIn.value }
        #expect(try await repository.dailyRecoveries(from: now.addingTimeInterval(-86_400), to: now.addingTimeInterval(86_400)).count == 1)
    }
}
