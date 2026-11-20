import Foundation
import PulseDomain
@testable import PulseServices
import Testing

/// Le ±2,5 kg du calculateur et la barre et les disques du profil (spec M4 §19.2).
struct PlateLoadSessionTests {
    private typealias Fix = LiveFixtures
    private let flatBench = [Fix.done(Fix.bench, 60, 10), Fix.done(Fix.bench, 60, 9), Fix.done(Fix.bench, 60, 8)]

    @Test func theRemainingWorkingSetsTakeTheNewLoad() {
        var session = Fix.session(Fix.launch(Fix.day([Fix.exercise(Fix.bench)]), nil), history: [Fix.bench: flatBench])
        let bench = session.exercises[0]
        session.applyStructure(.validate(exercise: bench.id, set: bench.sets[0].id), now: .t0)
        session.applyStructure(.setRemainingLoad(exercise: bench.id, weightKg: 62.5), now: .t0)
        let sets = session.exercises[0].sets
        // La série validée garde sa charge ; les deux suivantes passent à 62,5 kg, marquées modifiées.
        #expect(sets.map(\.weightKg) == [60, 62.5, 62.5])
        #expect(sets.map(\.isEdited) == [false, true, true])
        session.applyStructure(.setRemainingLoad(exercise: bench.id, weightKg: -5), now: .t0)
        #expect(session.exercises[0].sets.map(\.weightKg) == [60, 62.5, 62.5])
    }

    @Test func theWarmUpFollowsTheNewLoad() {
        var session = Fix.session(Fix.launch(Fix.day([Fix.exercise(Fix.bench)]), nil), history: [Fix.bench: flatBench],
                                  warmups: true)
        let bench = session.exercises[0]
        session.applyStructure(.setRemainingLoad(exercise: bench.id, weightKg: 100), now: .t0)
        #expect(session.exercises[0].sets.filter { $0.setType == .warmup }.map(\.weightKg) == [20, 60, 80])
    }

    @Test func barAndPlatesAreReadFromAndSavedToTheProfile() async throws {
        let fixture = ActiveSessionFixture()
        let service = fixture.makeService()
        // Sans profil : la salle courante, et rien n'est enregistré.
        let fallback = try await service.barAndPlates()
        #expect(fallback.barKg == 20 && fallback.platesKg == [25, 20, 15, 10, 5, 2.5, 1.25])
        try await service.saveBarAndPlates(barKg: 15, platesKg: [5])
        #expect(try await fixture.profiles.load() == nil)

        try await fixture.profiles.save(UserProfile(createdAt: .t0, updatedAt: .t0))
        try await service.saveBarAndPlates(barKg: 15, platesKg: [1.25, 0, 20, 10])
        let saved = try #require(try await fixture.profiles.load())
        #expect(saved.barWeightKg == 15 && saved.availablePlatesKg == [20, 10, 1.25])
        let read = try await service.barAndPlates()
        #expect(read.barKg == 15 && read.platesKg == [20, 10, 1.25])
    }
}
