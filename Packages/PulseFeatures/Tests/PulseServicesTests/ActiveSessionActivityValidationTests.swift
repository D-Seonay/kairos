import Foundation
import PulseDomain
import PulseServices
import Testing

/// « Valider » de la Live Activity : la série suivante affichée se coche avec sa proposition, la séance réagit comme à la coche
/// de l'écran de séance, et une activité en retard sur la séance ne coche rien.
struct ActiveSessionActivityValidationTests {
    private typealias Fix = LiveFixtures
    private let fixture = ActiveSessionFixture()

    @Test func theActivityOffersTheNextSet() async throws {
        let (service, session) = try await fixture.startPush()
        let bench = session.exercises[0]
        #expect(await fixture.activity.states.last?.nextSetID == bench.sets[0].id)
        _ = try await service.apply(.validate(exercise: bench.id, set: bench.sets[0].id))
        #expect(await fixture.activity.states.last?.nextSetID == bench.sets[1].id)
    }

    @Test func validatingFromTheActivityChecksTheProposedSetAndStartsTheRest() async throws {
        let (service, session) = try await fixture.startPush()
        let bench = session.exercises[0]
        let proposed = bench.sets[0].proposed
        let validated = try #require(try await service.validateFromActivity(set: bench.sets[0].id))
        let set = validated.exercises[0].sets[0]
        #expect(set.completedAt == fixture.clock.now)
        #expect(set.weightKg == proposed.weightKg && set.reps == proposed.reps)
        // Comme la coche de l'écran : le repos de l'exercice, sa notification, et l'activité qui avance.
        #expect(validated.rest == LiveRest(startedAt: fixture.clock.now, endsAt: fixture.clock.now.addingTimeInterval(165),
                                           exerciseID: bench.id))
        #expect(await fixture.notifier.scheduled.map(\.message.body) == ["Développé couché à la barre, série 2 : 70 kg × 5"])
        let state = try #require(await fixture.activity.states.last)
        #expect(state.doneSets == 1 && state.restEndsAt == validated.rest?.endsAt && state.nextSetID == bench.sets[1].id)
        #expect(try await fixture.stored() == validated)
    }

    @Test func anOutdatedActivityChecksNothing() async throws {
        let (service, session) = try await fixture.startPush()
        let bench = session.exercises[0]
        _ = try await service.validateFromActivity(set: bench.sets[0].id)
        let states = await fixture.activity.states.count
        // Un second appui sur la même série, ou une série qui n'est pas la suivante : rien ne bouge.
        #expect(try await service.validateFromActivity(set: bench.sets[0].id) == nil)
        #expect(try await service.validateFromActivity(set: session.exercises[1].sets[0].id) == nil)
        #expect(try await fixture.stored()?.doneWorkingSets == 1)
        #expect(await fixture.activity.states.count == states)
    }

    @Test func aSetWithoutItsLoadIsNotOffered() async throws {
        // Sans historique, le développé couché n'a pas de charge proposée : l'app ouvrirait le clavier.
        let service = fixture.makeService()
        let session = try await service.start(Fix.launch(Fix.day([Fix.exercise(Fix.bench, order: 0)]), nil))
        let bench = session.exercises[0]
        #expect(session.activityValidation == nil)
        #expect(await fixture.activity.states.last?.nextSetID == nil)
        #expect(try await service.validateFromActivity(set: bench.sets[0].id) == nil)
        // Une charge saisie dans l'app rend la série validable depuis l'activité.
        _ = try await service.apply(.edit(exercise: bench.id, set: bench.sets[0].id, weightKg: 60))
        #expect(await fixture.activity.states.last?.nextSetID == bench.sets[0].id)
        #expect(try await service.validateFromActivity(set: bench.sets[0].id)?.exercises[0].sets[0].weightKg == 60)
    }

    @Test func noSetIsOfferedOnceEverySetIsDoneOrForAPastSession() async throws {
        let service = fixture.makeService()
        let session = try await service.start(Fix.launch(Fix.day([Fix.exercise(Fix.pullUp, order: 0, sets: 1)]), nil))
        let pullUp = session.exercises[0]
        #expect(session.activityValidation?.set == pullUp.sets[0].id)
        let done = try #require(try await service.validateFromActivity(set: pullUp.sets[0].id))
        #expect(done.activityValidation == nil)
        #expect(await fixture.activity.states.last?.nextSetID == nil)
        var past = session
        past.pastEndedAt = session.startedAt.addingTimeInterval(3_600)
        #expect(past.activityValidation == nil)
    }
}
