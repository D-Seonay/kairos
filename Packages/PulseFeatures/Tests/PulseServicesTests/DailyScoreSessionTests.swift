import Foundation
import PulseDomain
import PulseServices
import Testing

/// Le score du jour et la séance prévue : ajustements enregistrés, choix « Séance d'origine », ressenti ajouté au score mesuré,
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

    /// Le ressenti du matin compte aussi quand le score est mesuré (#119) : enregistré à côté, il retire au plus 5 points.
    @Test func checkInAddsTheFeelingToAMeasuredScore() async throws {
        let fixture = fixture()
        let now = TestClock.date("2026-11-02T08:00")
        let measured = try scored(try await fixture.service.update(nights: await nights(.goodNight, at: now), now: now))
        let feelingBad = CheckInAnswers(sleep: 0, pain: 0, motivation: 0)
        let adjusted = try await fixture.service.saveCheckIn(feelingBad, now: TestClock.date("2026-11-02T09:00"))
        #expect(!adjusted.isEstimated)
        #expect(abs(adjusted.score - (measured.score - 5)) < 1e-9)
        #expect(adjusted.hrvScore == measured.hrvScore && adjusted.sleepScore == measured.sleepScore)
        #expect(adjusted.measuredScore.map { abs($0 - measured.score) < 1e-9 } == true)
        #expect(try await records(fixture, on: "2026-11-02T00:00") == [adjusted])
        let day = TestClock.date("2026-11-02T00:00")
        let checkIns = try await fixture.repository.checkIns(from: day, to: TestClock.date("2026-11-03T00:00"))
        #expect(checkIns.map(\.answers) == [feelingBad])
    }

    /// Un recalcul avant midi garde le ressenti enregistré : le score ne revient pas à la mesure seule.
    @Test func aRecomputeKeepsTheFeeling() async throws {
        let fixture = fixture()
        let now = TestClock.date("2026-11-02T08:00")
        let nights = await nights(.goodNight, at: now)
        _ = try await fixture.service.update(nights: nights, now: now)
        let adjusted = try await fixture.service.saveCheckIn(CheckInAnswers(sleep: 0, pain: 0, motivation: 0), now: now)
        let later = TestClock.date("2026-11-02T10:00")
        let recomputed = try scored(try await fixture.service.update(nights: nights, now: later))
        #expect(recomputed.score == adjusted.score)
        #expect(recomputed.category == adjusted.category)
    }

    /// Le ressenti peut alléger la séance (catégorie plus basse), jamais la durcir.
    @Test func feelingWorseCanLightenTheSession() async throws {
        let fixture = fixture()
        let now = TestClock.date("2026-11-02T08:00")
        let monday = try plannedDay(at: now)
        let measured = try scored(try await fixture.service.update(nights: await nights(.badNight, at: now), plannedDay: monday,
                                                                   now: now))
        let adjusted = try await fixture.service.saveCheckIn(CheckInAnswers(sleep: 0, pain: 0, motivation: 0), plannedDay: monday,
                                                             now: now)
        #expect(adjusted.score < measured.score)
        #expect(adjusted.category == RecoveryCategory(score: adjusted.score))
        let great = try await fixture.service.saveCheckIn(CheckInAnswers(sleep: 4, pain: 4, motivation: 4), plannedDay: monday,
                                                          now: now)
        #expect(great.category == measured.category, "Un bon ressenti ne fait jamais monter la catégorie")
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
        let measured = try scored(try await update.value)
        let adjusted = try await checkIn.value
        #expect(!adjusted.isEstimated, "Le check-in arrivé après la mesure s'y ajoute comme ressenti")
        #expect(adjusted.id == measured.id)
        #expect(try await repository.dailyRecoveries(from: now.addingTimeInterval(-86_400), to: now.addingTimeInterval(86_400)).count == 1)
    }

    @Test func unreadableProgramKeepsTheStoredAdjustmentsOnRecompute() async throws {
        let fixture = fixture()
        let early = TestClock.date("2026-11-02T07:00")
        let monday = try plannedDay(at: early)
        _ = try await fixture.service.update(nights: await nights(.badNight, at: early), plannedDay: monday, now: early)
        let later = TestClock.date("2026-11-02T09:00")
        let recomputed = try scored(try await fixture.service.update(nights: await nights(.badNight, at: later), plannedDay: nil,
                                                                     now: later))
        #expect(recomputed.adjustments.map(\.kind) == [.volume, .rpeCap, .rest])
        #expect(try await records(fixture, on: "2026-11-02T00:00").first?.adjustments.map(\.kind) == [.volume, .rpeCap, .rest])
    }

    @Test func unreadableProgramWithoutAStoredScoreStoresNoAdjustment() async throws {
        let fixture = fixture()
        let now = TestClock.date("2026-11-02T08:00")
        let recovery = try scored(try await fixture.service.update(nights: await nights(.badNight, at: now), plannedDay: nil, now: now))
        #expect(recovery.category == .moderateFatigue)
        #expect(recovery.adjustments.isEmpty)
    }

    @Test func unreadableProgramKeepsTheStoredAdjustmentsOnCheckIn() async throws {
        let fixture = fixture()
        let early = TestClock.date("2026-11-02T07:00")
        let monday = try plannedDay(at: early)
        let answers = CheckInAnswers(sleep: 1, pain: 1, motivation: 1)
        let first = try await fixture.service.saveCheckIn(answers, plannedDay: monday, now: early)
        #expect(first.adjustments.isEmpty == false)
        let again = try await fixture.service.saveCheckIn(answers, plannedDay: nil, now: TestClock.date("2026-11-02T09:00"))
        #expect(again.adjustments == first.adjustments)
    }
}
