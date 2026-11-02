import Foundation
import PulseDomain
import PulseRecoveryEngine
import PulseServices
import Testing

struct ActiveSessionServiceTests {
    private typealias Fix = LiveFixtures
    private let fixture = ActiveSessionFixture()

    @Test func startingWhileASessionExistsThrows() async throws {
        let (service, _) = try await fixture.startPush()
        await #expect(throws: ActiveSessionError.alreadyInProgress) { try await service.start(ActiveSessionFixture.pushLaunch) }
    }

    @Test func startStoresTheSessionAndStartsTheActivity() async throws {
        let (service, session) = try await fixture.startPush()
        #expect(session.title == "Push" && session.startedAt == fixture.clock.now && session.lastActionAt == fixture.clock.now)
        #expect(session.exercises.map(\.name) == ["Développé couché à la barre", "Écarté à la machine"])
        #expect(session.exercises[0].sets.map(\.proposed.weightKg) == [60, 70])
        #expect(session.policy == ProgressionPolicy(allowsIncrease: false))
        let snapshot = try #require(try await fixture.store.load())
        #expect(snapshot.id == session.id && snapshot.startedAt == session.startedAt && snapshot.updatedAt == fixture.clock.now)
        #expect(LiveSession.decode(snapshot.payload) == session)
        #expect(await service.current() == session)
        let states = await fixture.activity.states
        #expect(states.count == 1)
        #expect(states.first?.sessionID == session.id && states.first?.title == "Push" && states.first?.restEndsAt == nil)
        #expect(states.first?.nextSet == "Développé couché à la barre · série 1 · 60 kg × 12")
    }

    @Test func eachValidationIsStoredBeforeReturning() async throws {
        let (service, session) = try await fixture.startPush()
        _ = try await service.apply(.validate(exercise: session.exercises[0].id, set: session.exercises[0].sets[0].id))
        let stored = try #require(try await fixture.stored())
        #expect(stored.exercises[0].sets[0].completedAt == fixture.clock.now)
        #expect(stored.rest?.endsAt == fixture.clock.now.addingTimeInterval(165))   // 120 + 45 en fatigue
        #expect(await fixture.notifier.scheduled.last?.message.body == "Développé couché à la barre, série 2 : 70 kg × 5")
        #expect(await fixture.notifier.scheduled.last?.message.title == "Repos terminé")
    }

    @Test func validationTakesTheProposalForUneditedValues() async throws {
        let (service, session) = try await fixture.startPush()
        let bench = session.exercises[0]
        let after = try await service.apply(.validate(exercise: bench.id, set: bench.sets[0].id))
        let set = after.exercises[0].sets[0]
        #expect(set.weightKg == 60 && set.reps == 12 && !set.isEdited && set.completedAt == fixture.clock.now)
        // Une seconde validation ne déplace pas l'heure ; dévalider l'efface.
        fixture.clock.set("2026-11-02T08:01")
        let again = try await service.apply(.validate(exercise: bench.id, set: bench.sets[0].id))
        #expect(again.exercises[0].sets[0].completedAt == TestClock.date("2026-11-02T08:00"))
        let undone = try await service.apply(.unvalidate(exercise: bench.id, set: bench.sets[0].id))
        #expect(undone.exercises[0].sets[0].completedAt == nil)
        #expect(try await fixture.stored()?.exercises[0].sets[0].completedAt == nil)
    }

    @Test func firstValidatedSetSeedsTheFollowingUneditedSets() async throws {
        let (service, session) = try await fixture.startPush()
        let pecDeck = session.exercises[1]
        #expect(pecDeck.sets.count == 3 && pecDeck.lastTimeText == nil)
        _ = try await service.apply(.edit(exercise: pecDeck.id, set: pecDeck.sets[2].id, weightKg: 45, reps: 8))
        _ = try await service.apply(.edit(exercise: pecDeck.id, set: pecDeck.sets[0].id, weightKg: 40, reps: 10))
        let seeded = try await service.apply(.validate(exercise: pecDeck.id, set: pecDeck.sets[0].id)).exercises[1].sets
        #expect(seeded[1].proposed == ProposedSet(weightKg: 40, reps: 10))
        #expect(seeded[1].weightKg == 40 && seeded[1].reps == 10 && !seeded[1].isEdited)
        #expect(seeded[2].weightKg == 45 && seeded[2].reps == 8 && seeded[2].isEdited)
        // La deuxième série validée ne propage plus rien.
        _ = try await service.apply(.edit(exercise: pecDeck.id, set: pecDeck.sets[1].id, weightKg: 42.5))
        let second = try await service.apply(.validate(exercise: pecDeck.id, set: pecDeck.sets[1].id)).exercises[1].sets
        #expect(second[2].weightKg == 45 && second[2].proposed == pecDeck.sets[2].proposed)
    }

    @Test func anExerciseWithHistoryKeepsItsProposals() async throws {
        let (service, session) = try await fixture.startPush()
        let bench = session.exercises[0]
        _ = try await service.apply(.edit(exercise: bench.id, set: bench.sets[0].id, weightKg: 65))
        let after = try await service.apply(.validate(exercise: bench.id, set: bench.sets[0].id))
        #expect(after.exercises[0].sets[1] == bench.sets[1])
    }

    @Test func editsMarkTheSetAndKeepProposalsForTheOthers() async throws {
        let (service, session) = try await fixture.startPush()
        let bench = session.exercises[0]
        let edited = try await service.apply(.edit(exercise: bench.id, set: bench.sets[0].id, weightKg: 62.5))
        let set = edited.exercises[0].sets[0]
        #expect(set.weightKg == 62.5 && set.reps == 12 && set.isEdited && set.proposed.weightKg == 60)
        #expect(edited.exercises[0].sets[1] == bench.sets[1])
        // Le RPE seul ne rend pas la série modifiée ; `.some(nil)` l'efface, `nil` le laisse.
        let rated = try await service.apply(.edit(exercise: bench.id, set: bench.sets[1].id, rpe: 8.5))
        #expect(rated.exercises[0].sets[1].rpe == 8.5 && !rated.exercises[0].sets[1].isEdited)
        let kept = try await service.apply(.edit(exercise: bench.id, set: bench.sets[1].id, reps: 6))
        #expect(kept.exercises[0].sets[1].rpe == 8.5 && kept.exercises[0].sets[1].reps == 6)
        let cleared = try await service.apply(.edit(exercise: bench.id, set: bench.sets[1].id, rpe: .some(nil)))
        #expect(cleared.exercises[0].sets[1].rpe == nil && cleared.exercises[0].sets[1].reps == 6)
        // Une série modifiée garde ses valeurs à la validation.
        let validated = try await service.apply(.validate(exercise: bench.id, set: bench.sets[0].id))
        #expect(validated.exercises[0].sets[0].weightKg == 62.5)
    }

    @Test func setsCanBeTypedAddedAndDeleted() async throws {
        let (service, session) = try await fixture.startPush()
        let bench = session.exercises[0]
        let typed = try await service.apply(.setType(exercise: bench.id, set: bench.sets[0].id, .warmup))
        #expect(typed.exercises[0].sets[0].setType == .warmup)
        _ = try await service.apply(.edit(exercise: bench.id, set: bench.sets[1].id, weightKg: 72.5))
        let added = try await service.apply(.addSet(exercise: bench.id)).exercises[0].sets
        #expect(added.count == 3)
        #expect(added[2].proposed == ProposedSet(weightKg: 72.5, reps: 5))
        #expect(added[2].weightKg == 72.5 && added[2].reps == 5 && !added[2].isEdited && added[2].completedAt == nil)
        #expect(added[2].id != added[1].id && added[2].setType == .working)
        let deleted = try await service.apply(.deleteSet(exercise: bench.id, set: bench.sets[0].id)).exercises[0].sets
        #expect(deleted.map(\.id) == [bench.sets[1].id, added[2].id])
    }

    @Test func exercisesCanBeAddedMovedAndRemoved() async throws {
        let (service, session) = try await fixture.startPush()
        let added = try await service.newExercises([Fix.plank])
        #expect(added.map(\.name) == ["Planche"])
        let three = try await service.apply(.addExercises(added))
        #expect(three.exercises.map(\.id) == session.exercises.map(\.id) + added.map(\.id))
        let moved = try await service.apply(.moveExercise(added[0].id, by: -5))
        #expect(moved.exercises.map(\.id) == [added[0].id, session.exercises[0].id, session.exercises[1].id])
        let back = try await service.apply(.moveExercise(added[0].id, by: 1))
        #expect(back.exercises.map(\.id) == [session.exercises[0].id, added[0].id, session.exercises[1].id])
        let removed = try await service.apply(.removeExercise(session.exercises[0].id))
        #expect(removed.exercises.map(\.id) == [added[0].id, session.exercises[1].id])
        #expect(try await fixture.stored() == removed)
    }

    @Test func notesAndIncrementsAreKept() async throws {
        let (service, session) = try await fixture.startPush()
        let bench = session.exercises[0]
        fixture.clock.set("2026-11-02T08:05")
        let noted = try await service.apply(.setNote(exercise: bench.id, "Prise serrée"))
        #expect(noted.exercises[0].note == "Prise serrée" && noted.lastActionAt == fixture.clock.now)
        let blank = try await service.apply(.setNote(exercise: bench.id, "  "))
        #expect(blank.exercises[0].note == nil)
        let stepped = try await service.apply(.setIncrement(exercise: bench.id, 1.25))
        #expect(stepped.exercises[0].incrementKg == 1.25)
        let ignored = try await service.apply(.setIncrement(exercise: bench.id, 0))
        #expect(ignored.exercises[0].incrementKg == 1.25)
        #expect(try await fixture.stored()?.exercises[0].incrementKg == 1.25)
    }

    @Test func addedExercisesFollowTheDaysPolicyAfterARelaunch() async throws {
        try await fixture.seedHistory([Fix.done(Fix.pecDeck, 35, 12), Fix.done(Fix.pecDeck, 35, 12), Fix.done(Fix.pecDeck, 35, 12)])
        _ = try await fixture.makeService().start(Fix.launch(Fix.day([Fix.exercise(Fix.bench)]), .moderateFatigue))
        let relaunched = fixture.makeService()
        let added = try await relaunched.newExercises([Fix.pecDeck])
        #expect(added[0].sets.map(\.proposed.weightKg) == [35, 35, 35] && added[0].dayNote == "Même charge")
        #expect(added[0].lastTimeText == "Dernière fois 35 × 12 · 12 · 12")
    }

    @Test func changesWithoutASessionThrow() async throws {
        let service = fixture.makeService()
        #expect(await service.current() == nil)
        await #expect(throws: ActiveSessionError.noSession) { try await service.apply(.skipRest) }
        await #expect(throws: ActiveSessionError.noSession) { try await service.newExercises([Fix.bench]) }
    }

    @Test(arguments: ["pas du JSON", "{\"formatVersion\":2,\"exercises\":\"autre chose\"}"])
    func anUnreadableSnapshotDoesNotBlockANewSession(payload: String) async throws {
        try await fixture.store.save(ActiveSessionSnapshot(startedAt: .t0, updatedAt: .t0, payload: Data(payload.utf8)))
        let service = fixture.makeService()
        #expect(await service.current() == nil)
        await #expect(throws: ActiveSessionError.noSession) { try await service.apply(.skipRest) }
        // Elle ne pourra jamais être reprise : le départ l'efface avec sa Live Activity et sa notification.
        let session = try await service.start(ActiveSessionFixture.pushLaunch)
        #expect(try await fixture.stored() == session)
        #expect(try await fixture.store.load()?.id == session.id)
        #expect(await fixture.activity.endAllCalls == [nil])
        #expect(await fixture.notifier.cancelCount == 1)
        #expect(await service.current() == session)
    }

    @Test func aReadableSessionStillBlocksANewOne() async throws {
        let (service, session) = try await fixture.startPush()
        await #expect(throws: ActiveSessionError.alreadyInProgress) { try await service.start(ActiveSessionFixture.pushLaunch) }
        #expect(try await fixture.stored() == session)
        #expect(await fixture.activity.endAllCalls.isEmpty)
    }

    @Test func aFailedSaveThrowsAndLeavesTheStoredSessionAlone() async throws {
        let failing = FailingActiveSessionStore()
        let fixture = ActiveSessionFixture(store: failing)
        let (service, session) = try await fixture.startPush()
        await failing.setFailsOnSave(true)
        let bench = session.exercises[0]
        await #expect(throws: ActiveSessionError.notStored) {
            try await service.apply(.validate(exercise: bench.id, set: bench.sets[0].id))
        }
        #expect(try await fixture.stored() == session)
        #expect(await fixture.notifier.scheduled.isEmpty)
        #expect(await fixture.activity.states.count == 1)
        // L'écriture revient : le geste rejoué passe.
        await failing.setFailsOnSave(false)
        let validated = try await service.apply(.validate(exercise: bench.id, set: bench.sets[0].id))
        #expect(try await fixture.stored() == validated)
    }

    @Test func closingStaleActivitiesKeepsOnlyTheRunningSession() async throws {
        let service = fixture.makeService()
        await service.closeStaleActivities()
        let session = try await service.start(ActiveSessionFixture.pushLaunch)
        await service.closeStaleActivities()
        #expect(await fixture.activity.endAllCalls == [nil, session.id])
    }
}
