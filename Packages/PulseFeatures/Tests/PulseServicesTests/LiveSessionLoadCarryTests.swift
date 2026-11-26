import Foundation
import PulseDomain
import PulseRecoveryEngine
@testable import PulseServices
import Testing

/// La charge saisie sur une série de travail vaut pour les séries suivantes que Pulse propose encore.
struct LiveSessionLoadCarryTests {
    private typealias Fix = LiveFixtures
    private let fixture = ActiveSessionFixture()
    private let flatBench = [Fix.done(Fix.bench, 60, 10), Fix.done(Fix.bench, 60, 9), Fix.done(Fix.bench, 60, 8)]

    /// Un pec deck en `sets` séries, fait à 35 kg × 10 la dernière fois : toutes les séries sont proposées à 35 kg.
    private func startPecDeck(sets: Int = 3) async throws -> (ActiveSessionService, LiveExercise) {
        try await fixture.seedHistory((0..<sets).map { _ in Fix.done(Fix.pecDeck, 35, 10) })
        let service = fixture.makeService()
        let session = try await service.start(Fix.launch(Fix.day([Fix.exercise(Fix.pecDeck, sets: sets)]), nil))
        let pecDeck = try #require(session.exercises.first)
        #expect(pecDeck.sets.map(\.proposed.weightKg) == Array(repeating: 35, count: sets))
        return (service, pecDeck)
    }

    @Test func theTypedLoadOfTheFirstSetCarriesToTheFollowingSets() async throws {
        let (service, pecDeck) = try await startPecDeck()
        let sets = try await service.apply(.edit(exercise: pecDeck.id, set: pecDeck.sets[0].id, weightKg: 40)).exercises[0].sets
        #expect(sets.map(\.weightKg) == [40, 40, 40])
        // La série saisie est modifiée ; les suivantes restent des propositions, que la validation reprend.
        #expect(sets.map(\.isEdited) == [true, false, false])
        #expect(sets.map(\.proposed.weightKg) == [35, 40, 40])
        #expect(try await fixture.stored()?.exercises[0].sets.map(\.weightKg) == [40, 40, 40])
        let validated = try await service.apply(.validate(exercise: pecDeck.id, set: pecDeck.sets[1].id)).exercises[0].sets
        #expect(validated[1].weightKg == 40 && validated[1].completedAt != nil)
    }

    @Test func eachKeystrokeCarriesAgain() async throws {
        let (service, pecDeck) = try await startPecDeck()
        // « 4 », « 40 », effacé, puis « 45 » : les séries suivantes suivent la saisie jusqu'au bout.
        for typed in [4, 40, nil, 4, 45] as [Double?] {
            _ = try await service.apply(.edit(exercise: pecDeck.id, set: pecDeck.sets[0].id, weightKg: .some(typed)))
        }
        let sets = try #require(try await fixture.stored()).exercises[0].sets
        #expect(sets.map(\.weightKg) == [45, 45, 45])
        #expect(sets.map(\.isEdited) == [true, false, false])
    }

    @Test func anErasedLoadIsErasedOnTheFollowingSets() async throws {
        let (service, pecDeck) = try await startPecDeck()
        let sets = try await service.apply(.edit(exercise: pecDeck.id, set: pecDeck.sets[0].id, weightKg: .some(nil)))
            .exercises[0].sets
        #expect(sets.map(\.weightKg) == [nil, nil, nil])
        #expect(sets.map(\.proposed.weightKg) == [35, nil, nil])
    }

    @Test func repsAreNeverCarried() async throws {
        let (service, pecDeck) = try await startPecDeck()
        let reps = pecDeck.sets.map(\.reps)
        let both = try await service.apply(.edit(exercise: pecDeck.id, set: pecDeck.sets[0].id, weightKg: 40, reps: 6))
            .exercises[0].sets
        #expect(both.map(\.weightKg) == [40, 40, 40])
        #expect(both.map(\.reps) == [6, reps[1], reps[2]])
        #expect(both.dropFirst().map(\.proposed.reps) == [reps[1], reps[2]])
        // Les répétitions seules ne changent que leur série.
        let repsOnly = try await service.apply(.edit(exercise: pecDeck.id, set: pecDeck.sets[0].id, reps: 7)).exercises[0].sets
        #expect(Array(repsOnly.dropFirst()) == Array(both.dropFirst()))
    }

    @Test func validatedAndTypedSetsKeepTheirLoad() async throws {
        let (service, pecDeck) = try await startPecDeck(sets: 4)
        _ = try await service.apply(.validate(exercise: pecDeck.id, set: pecDeck.sets[1].id))
        _ = try await service.apply(.edit(exercise: pecDeck.id, set: pecDeck.sets[2].id, weightKg: 37.5))
        let typed = try #require(try await fixture.stored()).exercises[0].sets
        // La série 3, saisie à 37,5 kg, emmène la série 4, qui portait la même charge qu'elle.
        #expect(typed.map(\.weightKg) == [35, 35, 37.5, 37.5])
        _ = try await service.apply(.edit(exercise: pecDeck.id, set: pecDeck.sets[3].id, reps: 9))
        let sets = try await service.apply(.edit(exercise: pecDeck.id, set: pecDeck.sets[0].id, weightKg: 40)).exercises[0].sets
        // La série 2 est validée, la série 3 saisie, la série 4 modifiée (ses répétitions) : aucune ne bouge.
        #expect(sets.map(\.weightKg) == [40, 35, 37.5, 37.5])
        #expect(sets[1].completedAt != nil && sets[3].reps == 9)
    }

    @Test func theSetsBeforeTheTypedOneAreLeftAlone() async throws {
        let (service, pecDeck) = try await startPecDeck()
        let sets = try await service.apply(.edit(exercise: pecDeck.id, set: pecDeck.sets[1].id, weightKg: 40)).exercises[0].sets
        #expect(sets.map(\.weightKg) == [35, 40, 40])
        #expect(sets[0] == pecDeck.sets[0])
    }

    @Test func aFollowingSetWithAnotherLoadKeepsIt() async throws {
        // Bench en montée : 60 × 12 puis 70 × 5. Toucher la première série ne rabat pas la seconde.
        let (service, session) = try await fixture.startPush()
        let bench = session.exercises[0]
        #expect(bench.sets.map(\.weightKg) == [60, 70])
        let sets = try await service.apply(.edit(exercise: bench.id, set: bench.sets[0].id, weightKg: 62.5)).exercises[0].sets
        #expect(sets.map(\.weightKg) == [62.5, 70])
        #expect(sets[1] == bench.sets[1])
    }

    @Test func warmUpsNeitherCarryNorReceive() {
        var session = Fix.session(Fix.launch(Fix.day([Fix.exercise(Fix.bench)]), nil), history: [Fix.bench: flatBench],
                                  warmups: true)
        let bench = session.exercises[0]
        #expect(bench.sets.map(\.setType) == [.warmup, .warmup, .warmup, .working, .working, .working])
        // Une série d'échauffement saisie ne change qu'elle : ni les autres échauffements, ni les séries de travail.
        session.applyStructure(.edit(exercise: bench.id, set: bench.sets[0].id, weightKg: 60), now: .t0)
        #expect(session.exercises[0].sets.map(\.weightKg) == [60, 35, 47.5, 60, 60, 60])
        #expect(Array(session.exercises[0].sets.dropFirst()) == Array(bench.sets.dropFirst()))

        // Une série de travail redevenue échauffement à la main ne reçoit pas la charge.
        var retyped = Fix.session(Fix.launch(Fix.day([Fix.exercise(Fix.bench)]), nil), history: [Fix.bench: flatBench])
        let flat = retyped.exercises[0]
        retyped.applyStructure(.setType(exercise: flat.id, set: flat.sets[1].id, .warmup), now: .t0)
        retyped.applyStructure(.edit(exercise: flat.id, set: flat.sets[0].id, weightKg: 65), now: .t0)
        #expect(retyped.exercises[0].sets.map(\.weightKg) == [65, 60, 65])
    }

    @Test func theCarriedLoadIsWhatTheSessionRecords() async throws {
        let (service, pecDeck) = try await startPecDeck()
        _ = try await service.apply(.edit(exercise: pecDeck.id, set: pecDeck.sets[0].id, weightKg: 40))
        for set in pecDeck.sets {
            _ = try await service.apply(.validate(exercise: pecDeck.id, set: set.id))
        }
        let session = try #require(try await fixture.stored())
        let recorded = session.workoutSession(status: .completed, endedAt: fixture.clock.now, overallRPE: nil, note: nil,
                                              savedAt: fixture.clock.now)
        #expect(recorded.sets.map(\.actualWeightKg) == [40, 40, 40])
    }
}
