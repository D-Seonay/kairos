import Foundation
import PulseDomain
import PulseRecoveryEngine
import PulseServices
import Testing

struct ActiveSessionRestTests {
    private typealias Fix = LiveFixtures
    private let fixture = ActiveSessionFixture()

    private func start(_ exercises: [RoutineExercise]) async throws -> (ActiveSessionService, LiveSession) {
        let service = fixture.makeService()
        return (service, try await service.start(Fix.launch(Fix.day(exercises), nil)))
    }

    private func validate(_ service: ActiveSessionService, _ exercise: LiveExercise, _ set: Int) async throws -> LiveSession {
        try await service.apply(.validate(exercise: exercise.id, set: exercise.sets[set].id))
    }

    @Test func aWarmUpSetRestsSixtySeconds() async throws {
        let (service, session) = try await fixture.startPush()
        let bench = session.exercises[0]
        _ = try await service.apply(.setType(exercise: bench.id, set: bench.sets[0].id, .warmup))
        let rested = try await validate(service, bench, 0)
        #expect(rested.rest == LiveRest(startedAt: fixture.clock.now, endsAt: fixture.clock.now.addingTimeInterval(60),
                                        exerciseID: bench.id))
    }

    @Test func supersetRestStartsAfterTheSecondExercise() async throws {
        let (service, session) = try await start([Fix.exercise(Fix.bench, order: 0, rest: 120, superset: 1),
                                                  Fix.exercise(Fix.pecDeck, order: 1, rest: 75, superset: 1)])
        let (bench, pecDeck) = (session.exercises[0], session.exercises[1])
        #expect(try await validate(service, bench, 0).rest == nil)
        #expect(await fixture.notifier.scheduled.isEmpty)
        let paired = try await validate(service, pecDeck, 0)
        #expect(paired.rest == LiveRest(startedAt: fixture.clock.now, endsAt: fixture.clock.now.addingTimeInterval(75),
                                        exerciseID: pecDeck.id))
        #expect(await fixture.notifier.scheduled.map(\.message.body) == ["Développé couché à la barre, série 2 : 8 rép."])
        // Repartir sur le tour suivant avant la fin du repos l'arrête.
        #expect(try await validate(service, bench, 1).rest == nil)
        #expect(await fixture.notifier.cancelCount == 1)
    }

    @Test func theLastSetStartsNoRest() async throws {
        let (service, session) = try await start([Fix.exercise(Fix.pecDeck, sets: 2)])
        let pecDeck = session.exercises[0]
        // La deuxième série validée en premier n'est pas la dernière : la première reste à faire.
        #expect(try await validate(service, pecDeck, 1).rest?.endsAt == fixture.clock.now.addingTimeInterval(90))
        let done = try await validate(service, pecDeck, 0)
        #expect(done.rest == nil)
        #expect(await fixture.notifier.cancelCount == 1)
        #expect(await fixture.notifier.scheduled.count == 1)
    }

    @Test func restControlsMoveTheEndDateAndTheNotification() async throws {
        let (service, session) = try await fixture.startPush()
        let start = fixture.clock.now
        _ = try await validate(service, session.exercises[0], 0)
        let longer = try await service.apply(.restPlus30)
        #expect(longer.rest?.endsAt == start.addingTimeInterval(195) && longer.rest?.startedAt == start)
        #expect(await fixture.notifier.scheduled.last?.date == start.addingTimeInterval(195))
        let shorter = try await service.apply(.restMinus30)
        #expect(shorter.rest?.endsAt == start.addingTimeInterval(165))
        #expect(await fixture.notifier.scheduled.map(\.date) == [165, 195, 165].map { start.addingTimeInterval($0) })
        // −30 s ne remonte jamais avant maintenant : à 8 h 03, un repos jusqu'à 8 h 03 min 15 se termine.
        _ = try await service.apply(.restPlus30)
        fixture.clock.set("2026-11-02T08:03")
        let ended = try await service.apply(.restMinus30)
        #expect(ended.rest == nil)
        #expect(await fixture.notifier.cancelCount == 1)
        // Sans repos, les boutons ne font rien.
        #expect(try await service.apply(.restPlus30).rest == nil)
        // Passer annule.
        _ = try await validate(service, session.exercises[0], 1)
        #expect(try await service.apply(.skipRest).rest == nil)
        #expect(await fixture.notifier.cancelCount == 2)
        #expect(try await fixture.stored()?.rest == nil)
    }

    @Test func concurrentRestControlsAreSerialised() async throws {
        let (service, session) = try await start([Fix.exercise(Fix.bench, order: 0, rest: 400), Fix.exercise(Fix.pecDeck, order: 1)])
        let rest = try #require(try await validate(service, session.exercises[0], 0).rest)
        try await withThrowingTaskGroup(of: Void.self) { group in
            for index in 0..<20 {
                group.addTask { _ = try await service.apply(index.isMultiple(of: 2) ? .restPlus30 : .restMinus30) }
            }
            try await group.waitForAll()
        }
        let stored = try #require(try await fixture.stored())
        #expect(stored.rest == rest)
        #expect(await service.current() == stored)
        #expect(await fixture.notifier.scheduled.count == 21)
        #expect(await fixture.notifier.scheduled.last?.date == rest.endsAt)
    }

    @Test func resumingAfterTheRestEndedShowsNoRest() async throws {
        let (_, session) = try await fixture.startPush()
        let validated = try await validate(fixture.makeService(), session.exercises[0], 0)
        #expect(validated.rest?.endsAt == TestClock.date("2026-11-02T08:02").addingTimeInterval(45))
        // Toujours en cours à 8 h 01 : la reprise le garde, sans rien toucher.
        fixture.clock.set("2026-11-02T08:01")
        #expect(await fixture.makeService().current()?.rest == validated.rest)
        #expect(await fixture.notifier.cancelCount == 0)
        fixture.clock.set("2026-11-02T08:10")
        let resumed = try #require(await fixture.makeService().current())
        #expect(resumed.rest == nil && resumed.startedAt == session.startedAt)
        #expect(resumed.lastActionAt == TestClock.date("2026-11-02T08:00"))
        #expect(await fixture.notifier.cancelCount == 1)
        #expect(try await fixture.stored() == resumed)
        #expect(await fixture.activity.states.last?.restEndsAt == nil)
    }

    @Test func aChangeClearsARestThatEnded() async throws {
        let (service, session) = try await fixture.startPush()
        let bench = session.exercises[0]
        _ = try await validate(service, bench, 0)
        fixture.clock.set("2026-11-02T08:10")
        let edited = try await service.apply(.edit(exercise: bench.id, set: bench.sets[1].id, reps: 6))
        #expect(edited.rest == nil)
        #expect(await fixture.notifier.cancelCount == 1)
    }

    @Test func unvalidatingTheSetThatStartedTheRestStopsIt() async throws {
        let (service, session) = try await fixture.startPush()
        let bench = session.exercises[0]
        _ = try await validate(service, bench, 0)
        let undone = try await service.apply(.unvalidate(exercise: bench.id, set: bench.sets[0].id))
        #expect(undone.rest == nil)
        #expect(await fixture.notifier.cancelCount == 1)
    }

    @Test func disabledRestNotificationsScheduleNothing() async throws {
        try await fixture.setRestNotifications(enabled: false)
        let (service, session) = try await fixture.startPush()
        let rested = try await validate(service, session.exercises[0], 0)
        #expect(rested.rest != nil)
        _ = try await service.apply(.restPlus30)
        #expect(await fixture.notifier.scheduled.isEmpty)
    }

    @Test func theActivityShowsTheRestAndTheNextSet() async throws {
        let (service, session) = try await fixture.startPush()
        let bench = session.exercises[0]
        _ = try await validate(service, bench, 0)
        let resting = try #require(await fixture.activity.states.last)
        #expect(resting.restStartedAt == fixture.clock.now && resting.restEndsAt == fixture.clock.now.addingTimeInterval(165))
        #expect(resting.nextSet == "Développé couché à la barre · série 2 · 70 kg × 5")
        // Une série qui n'est pas la suivante ne change rien à l'écran verrouillé.
        let pecDeck = session.exercises[1]
        _ = try await service.apply(.edit(exercise: pecDeck.id, set: pecDeck.sets[2].id, weightKg: 30))
        #expect(await fixture.activity.states.count == 2)
        #expect(await fixture.notifier.scheduled.count == 1)
        // La suivante, si : l'activité et la notification suivent.
        _ = try await service.apply(.edit(exercise: bench.id, set: bench.sets[1].id, weightKg: 72.5))
        #expect(await fixture.activity.states.last?.nextSet == "Développé couché à la barre · série 2 · 72,5 kg × 5")
        #expect(await fixture.notifier.scheduled.last?.message.body == "Développé couché à la barre, série 2 : 72,5 kg × 5")
        #expect(await fixture.notifier.scheduled.last?.date == fixture.clock.now.addingTimeInterval(165))
        _ = try await service.apply(.skipRest)
        #expect(await fixture.activity.states.last?.restEndsAt == nil)
    }

    @Test func aSkippedSetDoesNotHoldTheNextSet() async throws {
        let (service, session) = try await start([Fix.exercise(Fix.bench, order: 0), Fix.exercise(Fix.pecDeck, order: 1)])
        let (bench, pecDeck) = (session.exercises[0], session.exercises[1])
        _ = try await validate(service, bench, 0)
        fixture.clock.set("2026-11-02T08:05")
        _ = try await validate(service, bench, 1)
        // Bench 3 sauté : après le pec deck 1, la suite est le pec deck 2.
        fixture.clock.set("2026-11-02T08:10")
        _ = try await validate(service, pecDeck, 0)
        #expect(await fixture.notifier.scheduled.last?.message.body == "\(pecDeck.name), série 2 : 8 rép.")
        #expect(await fixture.activity.states.last?.nextSet == "\(pecDeck.name) · série 2 · 8 rép.")
    }

    @Test func nextSetTextsFollowTheLoadKind() async throws {
        let service = fixture.makeService()
        _ = try await service.start(.free(policy: ProgressionPolicy(allowsIncrease: true)))
        let added = try await service.newExercises([Fix.plank, Fix.pullUp])
        let session = try await service.apply(.addExercises(added))
        #expect(await fixture.activity.states.last?.nextSet == "Planche · série 1 · 30 s")
        _ = try await service.apply(.removeExercise(session.exercises[0].id))
        #expect(await fixture.activity.states.last?.nextSet == "Tractions · série 1 · 8 rép.")
        let pullUp = session.exercises[1]
        _ = try await service.apply(.edit(exercise: pullUp.id, set: pullUp.sets[0].id, weightKg: 10))
        #expect(await fixture.activity.states.last?.nextSet == "Tractions · série 1 · +10 kg × 8")
        _ = try await validate(service, pullUp, 0)
        // Sans historique, la série validée devient la proposition des suivantes.
        #expect(await fixture.notifier.scheduled.last?.message.body == "Tractions, série 2 : +10 kg × 8")
    }
}
