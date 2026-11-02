import Foundation
import PulseDomain
@testable import PulsePersistence
import SwiftData
import Testing

@Test func settingsAreReplacedPerExercise() async throws {
    let repo = SwiftDataExerciseSettingsRepository(modelContainer: try TestContainer.make())
    let cable = ExerciseReference.content(id: "triceps-pushdown-cable")
    try await repo.save(ExerciseSettings(exercise: cable, incrementKg: 2.5, warmupSetCount: nil, createdAt: Fixed.t0, updatedAt: Fixed.t0))
    try await repo.save(ExerciseSettings(exercise: cable, incrementKg: 3.5, warmupSetCount: nil, createdAt: Fixed.t1, updatedAt: Fixed.t1))
    #expect(try await repo.all().count == 1)
    #expect(try await repo.settings(for: cable)?.incrementKg == 3.5)
    #expect(try await repo.settings(for: .content(id: "pec-deck-machine")) == nil)
}

@Test func savingSettingsAgainKeepsTheStoredID() async throws {
    let repo = SwiftDataExerciseSettingsRepository(modelContainer: try TestContainer.make())
    let custom = ExerciseReference.user(id: UUID())
    let first = ExerciseSettings(exercise: custom, incrementKg: 2.5, createdAt: Fixed.t0, updatedAt: Fixed.t0)
    try await repo.save(first)
    try await repo.save(ExerciseSettings(exercise: custom, incrementKg: nil, warmupSetCount: 3, createdAt: Fixed.t1, updatedAt: Fixed.t1))
    let stored = try #require(try await repo.settings(for: custom))
    #expect(stored.id == first.id && stored.incrementKg == nil && stored.warmupSetCount == 3)
    #expect(stored.createdAt == Fixed.t0)
}

@Test func settingsForAnExercisePickTheMostRecentDuplicate() async throws {
    let container = try TestContainer.make()
    let repo = SwiftDataExerciseSettingsRepository(modelContainer: container)
    let bench = ExerciseReference.content(id: "bench-press-barbell")
    // Deux enregistrements actifs pour le même exercice, comme après une restauration iCloud.
    let context = ModelContext(container)
    context.insert(StoredExerciseSettings(ExerciseSettings(exercise: bench, incrementKg: 1, createdAt: Fixed.t0, updatedAt: Fixed.t1)))
    context.insert(StoredExerciseSettings(ExerciseSettings(exercise: bench, incrementKg: 5, createdAt: Fixed.t0, updatedAt: Fixed.t2)))
    try context.save()
    #expect(try await repo.settings(for: bench)?.incrementKg == 5)
}
