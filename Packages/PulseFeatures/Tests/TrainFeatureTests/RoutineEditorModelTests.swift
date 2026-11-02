import Foundation
import PulseDomain
import PulseServices
import Testing
@testable import TrainFeature

private let bench = ExerciseReference.content(id: "bench-press-barbell")
private let chestPress = ExerciseReference.content(id: "chest-press-machine")
private let plank = ExerciseReference.content(id: "plank")

/// Un dépôt de programmes qui échoue à la lecture tant que `isFailing` est vrai.
private actor FlakyProgramRepository: ProgramRepository {
    enum Failure: Error { case unreadable }

    private let base: InMemoryProgramRepository
    private var isFailing = true

    init(base: InMemoryProgramRepository) {
        self.base = base
    }

    func recover() {
        isFailing = false
    }

    func programs(includeArchived: Bool) async throws -> [Program] {
        try await base.programs(includeArchived: includeArchived)
    }

    func program(id: UUID) async throws -> Program? {
        if isFailing { throw Failure.unreadable }
        return try await base.program(id: id)
    }

    func save(_ program: Program) async throws { try await base.save(program) }
    func delete(id: UUID) async throws { try await base.delete(id: id) }
}

/// Deux réglages pour le même exercice, comme après une restauration iCloud : le plus ancien d'abord.
private struct DuplicatedSettingsRepository: ExerciseSettingsRepository {
    let older: ExerciseSettings
    let newer: ExerciseSettings

    func all() async throws -> [ExerciseSettings] { [older, newer] }
    func settings(for exercise: ExerciseReference) async throws -> ExerciseSettings? { exercise == newer.exercise ? newer : nil }
    func save(_ settings: ExerciseSettings) async throws {}
}

/// Un programme actif de deux routines vides, « Push » et « Pull », et le modèle chargé sur « Push ».
@MainActor
private struct RoutineSetup {
    let fixture: TrainFixture
    let program: Program
    let push: UUID
    let pull: UUID

    init(fixture: TrainFixture = TrainFixture()) async throws {
        self.fixture = fixture
        let now = fixture.now
        let (withPush, push) = ProgramEditor.addDay(named: "Push", exercises: [], to: ProgramEditor.emptyProgram(name: "PPL", now: now),
                                                    now: now)
        let (program, pull) = ProgramEditor.addDay(named: "Pull", exercises: [], to: withPush, now: now)
        try await fixture.activate(program)
        self.program = program
        self.push = push
        self.pull = pull
    }

    func model() async -> RoutineEditorModel {
        let model = RoutineEditorModel(environment: fixture.environment, programID: program.id, dayID: push)
        await model.load()
        return model
    }

    func savedPush() async throws -> RoutineDay? {
        try await fixture.programs.program(id: program.id)?.days.first { $0.id == push }
    }
}

@MainActor @Test func routineEditorRefusesInvalidValuesAndSavesValidOnes() async throws {
    let setup = try await RoutineSetup()
    let model = await setup.model()
    model.add([bench, chestPress])
    model.setRest(310, at: 0)
    #expect(model.issues[0] == [.rest])
    #expect(model.issues[1] == nil)
    await #expect(throws: RoutineEditorError.invalid) { try await model.save() }
    #expect(try await setup.savedPush()?.exercises.isEmpty == true)
    model.setRest(120, at: 0)
    model.setPerSetTargets(true, at: 0)
    model.updateSetTarget(SetTarget(repsMin: 4, repsMax: 6), set: 1, at: 0)
    #expect(model.issues.isEmpty)
    try await model.save()
    let saved = try #require(try await setup.savedPush())
    #expect(saved.exercises.map(\.exercise) == [bench, chestPress])
    #expect(saved.exercises[0].restSeconds == 120)
    #expect(saved.exercises[0].setTargets?[1] == SetTarget(repsMin: 4, repsMax: 6))
    // Les séries suivantes qui avaient l'ancienne fourchette la prennent ; la première reste.
    #expect(saved.exercises[0].setTargets?[0] == SetTarget(repsMin: 8, repsMax: 12))
    #expect(saved.exercises[0].setTargets?[2] == SetTarget(repsMin: 4, repsMax: 6))
    #expect(saved.exercises[0].repsMin == 4)
    #expect(saved.exercises[0].repsMax == 12)
}

@MainActor @Test func savingTouchesOnlyThatRoutine() async throws {
    let setup = try await RoutineSetup()
    let model = await setup.model()
    model.add([bench])
    model.rename("  Push lourd  ")
    try await model.save()
    let program = try #require(try await setup.fixture.programs.program(id: setup.program.id))
    #expect(program.days.map(\.name) == ["Push lourd", "Pull"])
    #expect(program.days[1] == setup.program.days[1])
    #expect(program.updatedAt == setup.fixture.now)
    #expect(model.day.name == "Push lourd")
}

@MainActor @Test func aDraftIsOnlyPersistedBySaving() async throws {
    let setup = try await RoutineSetup()
    let model = await setup.model()
    #expect(!model.hasChanges)
    #expect(!model.canSave)
    model.add([bench])
    #expect(model.hasChanges)
    #expect(model.canSave)
    #expect(try await setup.savedPush()?.exercises.isEmpty == true)
    try await model.save()
    #expect(!model.hasChanges)
    model.rename("   ")
    #expect(model.hasChanges)
    #expect(!model.canSave)
    await #expect(throws: RoutineEditorError.invalid) { try await model.save() }
}

@MainActor @Test func loadingAgainKeepsTheDraft() async throws {
    let setup = try await RoutineSetup()
    let model = await setup.model()
    model.add([bench])
    await model.load()
    #expect(model.day.exercises.count == 1)
}

@MainActor @Test func addingExercisesGivesTheDefaultsAndUpdatesTheDuration() async throws {
    let setup = try await RoutineSetup()
    let model = await setup.model()
    #expect(model.estimatedMinutes == 0)
    model.add([bench])
    let exercise = model.day.exercises[0]
    #expect((exercise.sets, exercise.repsMin, exercise.repsMax, exercise.targetRPE) == (3, 8, 12, 8))
    let one = model.estimatedMinutes
    model.add([chestPress, plank])
    #expect(model.estimatedMinutes > one)
    // Un exercice tenu part sur 30 à 60 secondes.
    #expect((model.day.exercises[2].repsMin, model.day.exercises[2].repsMax) == (30, 60))
    #expect(model.issues.isEmpty)
    model.setRange(SetTarget(repsMin: 0, repsMax: 700), at: 2)
    #expect(model.issues[2] == [.reps])
}

@MainActor @Test func reorderingRemovingAndPairingSupersets() async throws {
    let setup = try await RoutineSetup()
    let model = await setup.model()
    model.add([bench, chestPress, plank])
    #expect(!model.isSuperset(at: 0))
    #expect(model.canToggleSuperset(at: 0))
    #expect(!model.canToggleSuperset(at: 2))
    model.toggleSuperset(at: 0)
    #expect(model.isSuperset(at: 0))
    #expect(!model.isSuperset(at: 1))
    model.move(fromOffsets: IndexSet(integer: 2), toOffset: 0)
    #expect(model.day.exercises.map(\.exercise) == [plank, bench, chestPress])
    #expect(model.isSuperset(at: 1))
    model.remove(at: 1)
    #expect(model.day.exercises.map(\.exercise) == [plank, chestPress])
    #expect(model.day.exercises.allSatisfy { $0.supersetGroup == nil })
    #expect(model.day.exercises.map(\.order) == [0, 1])
}

@MainActor @Test func setsRangeRpeAndPerSetTargetsStayInStep() async throws {
    let setup = try await RoutineSetup()
    let model = await setup.model()
    model.add([bench])
    model.setSets(5, at: 0)
    model.setRange(SetTarget(repsMin: 5, repsMax: 8), at: 0)
    model.setRPE(9.5, at: 0)
    #expect(model.day.exercises[0].sets == 5)
    #expect((model.day.exercises[0].repsMin, model.day.exercises[0].repsMax) == (5, 8))
    #expect(model.day.exercises[0].targetRPE == 9.5)
    #expect(model.issues.isEmpty)
    model.setPerSetTargets(true, at: 0)
    #expect(model.day.exercises[0].setTargets?.count == 5)
    // Avec une fourchette par série, la fourchette de l'exercice en découle : setRange ne la décale pas.
    model.setRange(SetTarget(repsMin: 1, repsMax: 2), at: 0)
    #expect((model.day.exercises[0].repsMin, model.day.exercises[0].repsMax) == (5, 8))
    model.setSets(2, at: 0)
    #expect(model.day.exercises[0].setTargets?.count == 2)
    model.setRPE(10.5, at: 0)
    #expect(model.issues[0] == [.rpe])
}

@MainActor @Test func theIncrementIsWrittenToTheExerciseSettings() async throws {
    let setup = try await RoutineSetup()
    let model = await setup.model()
    model.add([bench])
    // Sans réglage : le plus petit de l'incrément de l'exercice et de celui du profil.
    let initial = model.increment(for: bench)
    #expect(initial > 0)
    await model.setIncrement(1.3, for: bench)
    #expect(model.increment(for: bench) == 1.25)
    let stored = try await setup.fixture.environment.exerciseSettings.settings(for: bench)
    #expect(stored?.incrementKg == 1.25)
    await model.setIncrement(50, for: bench)
    #expect(model.increment(for: bench) == 20)
    // Un autre éditeur relit le réglage.
    let other = await setup.model()
    #expect(other.increment(for: bench) == 20)
}

/// Deux réglages du même exercice : l'éditeur garde le plus récent, comme `settings(for:)`.
@MainActor @Test func duplicatedSettingsKeepTheLatest() async throws {
    let date = TrainClock.date(day: 1, hour: 9)
    let older = ExerciseSettings(exercise: bench, incrementKg: 5, createdAt: date, updatedAt: date)
    let newer = ExerciseSettings(exercise: bench, incrementKg: 1.25, createdAt: date, updatedAt: date.addingTimeInterval(60))
    let setup = try await RoutineSetup(fixture: TrainFixture(exerciseSettings: DuplicatedSettingsRepository(older: older, newer: newer)))
    let model = await setup.model()
    model.add([bench])
    #expect(model.increment(for: bench) == 1.25)
}

@MainActor @Test func aMissingOrRunningDayIsNotEditable() async throws {
    let setup = try await RoutineSetup()
    let missing = RoutineEditorModel(environment: setup.fixture.environment, programID: setup.program.id, dayID: UUID())
    await missing.load()
    #expect(missing.isMissing)
    #expect(missing.hasLoaded)
    await #expect(throws: RoutineEditorError.missing) { try await missing.save() }
    let run = RoutineDay(order: 2, name: "Sortie", kind: .run, runType: .easy, runTargetMinutes: 40)
    var program = setup.program
    program.days.append(run)
    try await setup.fixture.programs.save(program)
    let running = RoutineEditorModel(environment: setup.fixture.environment, programID: program.id, dayID: run.id)
    await running.load()
    #expect(running.isMissing)
}

@MainActor @Test func aFailedLoadReportsAnErrorAndCanBeRetried() async throws {
    let setup = try await RoutineSetup()
    let flaky = FlakyProgramRepository(base: setup.fixture.programs)
    var environment = setup.fixture.environment
    environment.programs = flaky
    let model = RoutineEditorModel(environment: environment, programID: setup.program.id, dayID: setup.push)
    await model.load()
    // L'écran sort de l'indicateur : un message, ni routine lue ni routine introuvable.
    #expect(model.errorMessage != nil)
    #expect(!model.hasLoaded)
    #expect(!model.isMissing)
    await flaky.recover()
    await model.load()
    #expect(model.hasLoaded)
    #expect(!model.isMissing)
    #expect(model.errorMessage == nil)
    #expect(model.day.name == "Push")
}
