import Foundation
import PulseDomain
import PulseServices
import Testing
@testable import TodayFeature

/// La carte « Séance du jour » du modèle : ajustement au score, choix de la séance d'origine, feuilles de démarrage.
/// Lundi 2 novembre, PPL 3 : Push.
@MainActor
struct TodayModelSessionTests {
    private func strength(_ model: TodayModel) -> StrengthCard? {
        if case .strength(let card) = model.card { return card }
        Issue.record("Une carte de musculation était attendue, obtenu \(model.card)")
        return nil
    }

    @Test func badNightShowsTheAdjustedPush() async throws {
        let fixture = TodayFixture(scenario: .badNight)
        try await fixture.adopt("ppl-3")
        let model = fixture.makeModel()
        await model.refresh()
        let card = try #require(strength(model))
        #expect(card.badge == .adjusted)
        #expect(card.title == "Push, volume allégé")
        #expect(card.summary.setCount == 15)
        #expect(card.originButton == "Séance d'origine")
        #expect(model.session?.status == .adjusted)
    }

    @Test func customExercisesCountInTheSessionSummary() async throws {
        let fixture = TodayFixture(scenario: .goodNight)
        var program = try await fixture.adopt("ppl-3")
        let shrug = UserExercise(
            name: "Shrug (Haltère)", primaryMuscle: .traps, secondaryMuscles: [], equipment: .dumbbell, pattern: .shoulderIsolation,
            region: .upper, isUnilateral: false, defaultIncrementKg: 2.5, defaultRestSeconds: 60,
            createdAt: fixture.clock.now, updatedAt: fixture.clock.now)
        try await fixture.userExercises.save(shrug)
        program.days[0].exercises.append(RoutineExercise(
            order: 99, exercise: .user(id: shrug.id), sets: 4, repsMin: 10, repsMax: 12, targetRPE: 8, restSeconds: 60))
        try await fixture.programs.save(program)
        let model = fixture.makeModel()
        await model.refresh()
        let card = try #require(strength(model))
        #expect(card.summary.muscleWeights[.traps] == 4)
    }

    @Test func chooseOriginalSessionSwitchesTheCard() async throws {
        let fixture = TodayFixture(scenario: .badNight)
        try await fixture.adopt("ppl-3")
        let model = fixture.makeModel()
        await model.refresh()

        await model.chooseOriginalSession(true)
        #expect(model.session?.status == .restored)
        let restored = try #require(strength(model))
        #expect(restored.badge == .planned)
        #expect(restored.summary.setCount == 19)
        #expect(restored.originButton == "Revenir à l'ajustée")

        await model.chooseOriginalSession(false)
        #expect(model.session?.status == .adjusted)
        #expect(try #require(strength(model)).summary.setCount == 15)
    }

    @Test func theChoiceSurvivesARefresh() async throws {
        let fixture = TodayFixture(scenario: .badNight)
        try await fixture.adopt("ppl-3")
        let model = fixture.makeModel()
        await model.refresh()
        await model.chooseOriginalSession(true)
        fixture.clock.set("2026-11-02T09:00")
        await model.refresh()
        #expect(model.session?.status == .restored)
    }

    /// Un jour de fatigue : la carte lance le jour ajusté, avec le volume, le plafond de RPE et les repos appliqués.
    @Test func startingFromTheCardLaunchesTheAdjustedDay() async throws {
        let fixture = TodayFixture(scenario: .badNight)
        let program = try await fixture.adopt("ppl-3")
        let model = fixture.makeModel()
        await model.refresh()
        let adjusted = try #require(model.session?.adjusted?.day)
        let launch = try #require(model.sessionLaunch(startsOriginal: false))
        #expect(launch.day == adjusted)
        #expect(launch.plannedDay == model.session?.originalDay)
        #expect(launch.programID == program.id)
        #expect(launch.applied.map(\.kind) == [.volume, .rpeCap, .rest])
        #expect(launch.refused.isEmpty)
        #expect(!launch.policy.allowsIncrease)
    }

    /// « Séance d'origine » : le jour prévu est lancé et les ajustements de la catégorie sont refusés.
    @Test func originalChoiceLaunchesTheOriginalAndRefusesAdjustments() async throws {
        let fixture = TodayFixture(scenario: .badNight)
        try await fixture.adopt("ppl-3")
        let model = fixture.makeModel()
        await model.refresh()
        await model.chooseOriginalSession(true)
        let original = try #require(model.session?.originalDay)
        let launch = try #require(model.sessionLaunch(startsOriginal: true))
        #expect(launch.day == original)
        #expect(launch.applied.isEmpty)
        #expect(launch.refused.map(\.kind) == [.volume, .rpeCap, .rest])
    }

    @Test func noLaunchWithoutAStrengthCard() async throws {
        let fixture = TodayFixture(at: "2026-11-03T08:00")
        try await fixture.adopt("ppl-3")
        let model = fixture.makeModel()
        await model.refresh()
        #expect(model.sessionLaunch(startsOriginal: false) == nil)
    }

    /// Une séance terminée aujourd'hui remplace « Démarrer » par son bilan ; celle d'hier ou une séance abandonnée, non.
    @Test func aDoneSessionReplacesStart() async throws {
        let fixture = TodayFixture(scenario: .goodNight)
        try await fixture.adopt("ppl-3")
        let bench = ExerciseReference.content(id: "bench-press-barbell")
        let sets = (0..<4).map { index in
            WorkoutSet(order: index, exercise: bench, exerciseName: "Développé couché", setType: .working, actualWeightKg: 60,
                       actualReps: 10, completedAt: TodayClock.date("2026-11-02T06:40"), isPersonalRecord: index == 3)
        }
        let warmUp = WorkoutSet(order: 4, exercise: bench, exerciseName: "Développé couché", setType: .warmup, actualWeightKg: 20,
                                actualReps: 10, completedAt: TodayClock.date("2026-11-02T06:35"), isPersonalRecord: true)
        let start = TodayClock.date("2026-11-02T06:30")
        let done = WorkoutSession(startedAt: start, endedAt: TodayClock.date("2026-11-02T07:25"), kind: .strength, source: .pulse,
                                  status: .completed, title: "Push", tonnageKg: 2_400, durationMinutes: 55,
                                  sets: sets + [warmUp], createdAt: start, updatedAt: start)
        let yesterday = TodayClock.date("2026-11-01T18:00")
        try await fixture.workouts.save(done)
        try await fixture.workouts.save(WorkoutSession(
            startedAt: yesterday, endedAt: yesterday.addingTimeInterval(3_600), kind: .strength, source: .pulse, status: .completed,
            title: "Hier", durationMinutes: 60, createdAt: yesterday, updatedAt: yesterday))
        let model = fixture.makeModel()
        await model.refresh()
        #expect(model.card == .done(DoneCard(title: "Push", durationMinutes: 55, setCount: 4, tonnageKg: 2_400, recordCount: 1)))
    }

    @Test func anAbandonedSessionDoesNotReplaceStart() async throws {
        let fixture = TodayFixture(scenario: .goodNight)
        try await fixture.adopt("ppl-3")
        let start = TodayClock.date("2026-11-02T06:30")
        try await fixture.workouts.save(WorkoutSession(
            startedAt: start, endedAt: TodayClock.date("2026-11-02T06:50"), kind: .strength, source: .pulse, status: .abandoned,
            title: "Push", durationMinutes: 20, createdAt: start, updatedAt: start))
        let model = fixture.makeModel()
        await model.refresh()
        #expect(try #require(strength(model)).startButton == "Démarrer la séance")
    }

    /// Une séance en cours remplace la carte par « Reprendre la séance », quel que soit le jour.
    @Test func aStoredLiveSessionShowsResume() async throws {
        let fixture = TodayFixture(scenario: .goodNight)
        try await fixture.adopt("ppl-3")
        let model = fixture.makeModel()
        await model.refresh()
        let launch = try #require(model.sessionLaunch(startsOriginal: false))
        _ = try await fixture.liveSession.start(launch)
        await model.refresh()
        #expect(model.card == .inProgress(title: "Push"))
        #expect(model.sessionLaunch(startsOriginal: false) == nil)
    }

    @Test func startMobilityOpensTheSheet() async throws {
        let fixture = TodayFixture(at: "2026-11-03T08:00")
        try await fixture.adopt("ppl-3")
        let model = fixture.makeModel()
        await model.refresh()
        model.startMobility()
        #expect(model.sheet == .mobility)
    }

    /// Avant 4 h, aucun score du jour : la séance reste planifiée et la carte ne propose pas la séance d'origine.
    @Test func beforeFourOffersNoOriginalSession() async throws {
        let fixture = TodayFixture(scenario: .badNight, at: "2026-11-02T03:00")
        try await fixture.adopt("ppl-3")
        let model = fixture.makeModel()
        await model.refresh()
        let card = try #require(strength(model))
        #expect(card.badge == .planned)
        #expect(card.originButton == nil)
        #expect(!card.showsWhy)
    }

    /// Un check-in très bas (25) sur Push : surmenage, la carte propose mobilité ou repos, et « Démarrer » ne lance rien.
    @Test func overreachedCheckInProposesMobilityOrRest() async throws {
        let fixture = TodayFixture(scenario: .threeNights)
        try await fixture.adopt("ppl-3")
        let model = fixture.makeModel()
        await model.refresh()
        #expect(try #require(strength(model)).badge == .planned)

        model.checkIn.selection = [.sleep: 1, .pain: 1, .motivation: 1]
        await model.submitCheckIn()
        #expect(model.card == .mobilityOrRest(dayName: "Push"))
        #expect(model.sessionLaunch(startsOriginal: false) == nil)

        await model.chooseOriginalSession(true)
        let restored = try #require(strength(model))
        #expect(restored.startButton == "Démarrer quand même")
        let launch = try #require(model.sessionLaunch(startsOriginal: true))
        #expect(launch.day == model.session?.originalDay)
        #expect(launch.refused.map(\.kind) == [.replaceWithMobility])
    }

    /// Un score mesuré arrivé entre-temps refuse le check-in : l'accueil se relit au lieu d'afficher une erreur.
    @Test func checkInOverAMeasuredScoreRefreshes() async throws {
        let fixture = TodayFixture(scenario: .threeNights)
        try await fixture.adopt("ppl-3")
        let model = fixture.makeModel()
        await model.refresh()
        guard case .needsCheckIn = model.score else {
            Issue.record("Un check-in était attendu, obtenu \(String(describing: model.score))")
            return
        }
        let now = fixture.clock.now
        let measured = DailyRecovery(day: TodayClock.date("2026-11-02T00:00"), score: 72, category: .normal, isEstimated: false,
                                     calibration: .ready, createdAt: now, updatedAt: now)
        try await fixture.recovery.save(measured)

        model.checkIn.selection = [.sleep: 3, .pain: 3, .motivation: 3]
        await model.submitCheckIn()
        #expect(model.errorMessage == nil)
        #expect(model.score == .scored(measured))
    }
}
