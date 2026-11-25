import Foundation
import PulseDomain
@testable import PulseServices
import Testing

/// L'incrément choisi pendant la séance vaut aussi pour les séances suivantes (#49), comme le nombre de séries d'échauffement.
@Suite struct LiveSessionIncrementTests {
    private typealias Fix = LiveFixtures

    @Test func theIncrementIsSavedInTheExerciseSettings() async throws {
        let fixture = ActiveSessionFixture()
        let service = fixture.makeService()
        try await fixture.settings.save(ExerciseSettings(exercise: Fix.bench, warmupSetCount: 2, createdAt: .t0, updatedAt: .t0))
        try await service.saveIncrement(1.25, for: Fix.bench)
        let saved = try #require(try await fixture.settings.settings(for: Fix.bench))
        #expect(saved.incrementKg == 1.25 && saved.warmupSetCount == 2)
        try await service.saveIncrement(5, for: Fix.pecDeck)
        #expect(try await fixture.settings.settings(for: Fix.pecDeck)?.incrementKg == 5)
    }

    @Test func aZeroIncrementIsNotSaved() async throws {
        let fixture = ActiveSessionFixture()
        let service = fixture.makeService()
        try await service.saveIncrement(0, for: Fix.bench)
        #expect(try await fixture.settings.settings(for: Fix.bench) == nil)
    }
}
