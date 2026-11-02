import Foundation
import PulseContent
import PulseDomain
import PulseServices
import Testing
@testable import TrainFeature

@MainActor @Test func customExerciseNeedsANameAndKeepsTheDraft() async throws {
    let fixture = TrainFixture()
    let model = CustomExerciseModel(environment: fixture.environment, draft: HevyNameGuesser.draft(for: "Shrug (Haltère)"), editing: nil)
    #expect(model.canSave)
    model.name = "  "
    #expect(!model.canSave)
    model.name = "Shrug haltères"
    let saved = try await model.save()
    #expect(saved.primaryMuscle == .traps && saved.equipment == .dumbbell)
    #expect(try await fixture.environment.userExercises.all(includeArchived: false) == [saved])
}

@MainActor @Test func customExerciseStartsFromTheMachineDefaults() async throws {
    let fixture = TrainFixture()
    let model = CustomExerciseModel(environment: fixture.environment, draft: nil, editing: nil)
    #expect(model.equipment == .machine)
    #expect(model.pattern == .horizontalPush)
    #expect(model.region == .upper)
    #expect(model.loadKind == .external)
    #expect(model.incrementKg == 2.5)
    #expect(model.restSeconds == 90)
    #expect(model.secondaryMuscles.isEmpty)
    #expect(!model.isCompound && !model.tracksDuration && !model.isUnilateral)
    #expect(!model.canSave)
    model.name = "  Presse inclinée  "
    let saved = try await model.save()
    #expect(saved.name == "Presse inclinée")
    #expect(saved.createdAt == fixture.now && saved.updatedAt == fixture.now)
    #expect(!saved.isArchived)
}

@MainActor @Test func customExerciseRejectsASecondaryMuscleThatIsThePrimaryOne() async {
    let model = CustomExerciseModel(environment: TrainFixture().environment, draft: nil, editing: nil)
    model.name = "Fly"
    model.setPrimaryMuscle(.chest)
    model.secondaryMuscles = [.chest, .triceps]
    #expect(!model.canSave)
    await #expect(throws: CustomExerciseError.invalid) { try await model.save() }
    model.secondaryMuscles = [.triceps]
    #expect(model.canSave)
}

@MainActor @Test func customExerciseDropsTheNewPrimaryMuscleFromTheSecondaryOnes() {
    let model = CustomExerciseModel(environment: TrainFixture().environment, draft: nil, editing: nil)
    model.secondaryMuscles = [.triceps, .frontDelts]
    model.setPrimaryMuscle(.triceps)
    #expect(model.secondaryMuscles == [.frontDelts])
}

@MainActor @Test func customExerciseFollowsTheEquipmentAndRegionUntilTheUserTouchesTheValues() {
    let model = CustomExerciseModel(environment: TrainFixture().environment, draft: nil, editing: nil)
    model.setEquipment(.barbell)
    model.setRegion(.lower)
    #expect(model.incrementKg == 5)
    #expect(model.restSeconds == 180)
    model.restSeconds = 150
    model.setRegion(.upper)
    #expect(model.incrementKg == 2.5)
    #expect(model.restSeconds == 150)
    model.setEquipment(.cable)
    #expect(model.restSeconds == 150)
}

@MainActor @Test func customExerciseEditingKeepsItsIdentity() async throws {
    let fixture = TrainFixture()
    let original = userExercise(name: "Zercher squat")
    try await fixture.store(original)
    let model = CustomExerciseModel(environment: fixture.environment, draft: nil, editing: original)
    #expect(model.isEditing)
    #expect(model.name == "Zercher squat")
    #expect(model.primaryMuscle == .quads && model.secondaryMuscles == [.glutes])
    #expect(model.incrementKg == 5 && model.restSeconds == 120 && model.isCompound)
    model.name = "Zercher squat lourd"
    model.secondaryMuscles = [.glutes, .lowerBack]
    let saved = try await model.save()
    #expect(saved.id == original.id)
    #expect(saved.createdAt == original.createdAt)
    // Les muscles secondaires s'enregistrent dans l'ordre du catalogue, quel que soit l'ordre des touches.
    #expect(saved.secondaryMuscles == [.lowerBack, .glutes])
    let stored = try await fixture.environment.userExercises.all(includeArchived: true)
    #expect(stored == [saved])
}

@MainActor @Test func customExerciseArchivesWhatItEdits() async throws {
    let fixture = TrainFixture()
    let original = userExercise(name: "Zercher squat")
    try await fixture.store(original)
    let model = CustomExerciseModel(environment: fixture.environment, draft: nil, editing: original)
    try await model.archive()
    #expect(try await fixture.environment.userExercises.all(includeArchived: false).isEmpty)
    #expect(try await fixture.environment.userExercises.all(includeArchived: true).first?.isArchived == true)

    let creation = CustomExerciseModel(environment: fixture.environment, draft: nil, editing: nil)
    await #expect(throws: CustomExerciseError.notSaved) { try await creation.archive() }
}

@MainActor @Test func customExerciseCarriesTheDurationAndCompoundSwitches() async throws {
    let model = CustomExerciseModel(environment: TrainFixture().environment, draft: nil, editing: nil)
    model.name = "Planche lestée"
    model.isCompound = true
    model.tracksDuration = true
    model.isUnilateral = true
    model.loadKind = .bodyweight
    let saved = try await model.save()
    #expect(saved.isCompound && saved.tracksDuration && saved.isUnilateral)
    #expect(saved.loadKind == .bodyweight)
}
