import Foundation
import PulseDomain
import PulseServices
import Testing
@testable import TrainFeature

/// Un programme actif d'une routine « Push » et d'une course ajoutée d'un geste, et le modèle chargé sur la course.
@MainActor
private struct RunSetup {
    let fixture = TrainFixture()
    let program: Program
    let push: UUID
    let run: UUID

    init() async throws {
        let now = fixture.now
        let (withPush, push) = ProgramEditor.addDay(named: "Push", exercises: [],
                                                    to: ProgramEditor.emptyProgram(name: "Hybride", now: now), now: now)
        let (program, run) = ProgramEditor.addRunDay(to: withPush, now: now)
        try await fixture.activate(program)
        self.program = program
        self.push = push
        self.run = run
    }

    func model(day: UUID? = nil) async -> RunDayEditorModel {
        let model = RunDayEditorModel(environment: fixture.environment, programID: program.id, dayID: day ?? run)
        await model.load()
        return model
    }

    func savedRun() async throws -> RoutineDay? {
        try await fixture.programs.program(id: program.id)?.days.first { $0.id == run }
    }
}

@MainActor @Test func theRunEditorLoadsTheRunDayAndNothingElse() async throws {
    let setup = try await RunSetup()
    let model = await setup.model()
    #expect(model.hasLoaded && !model.isMissing && !model.hasChanges)
    #expect(model.type == .easy && model.goal == .minutes(30) && model.goalKind == .duration)
    let strength = await setup.model(day: setup.push)
    #expect(strength.hasLoaded && strength.isMissing, "Une routine de musculation a son propre éditeur")
    let unknown = await setup.model(day: UUID())
    #expect(unknown.isMissing)
    await #expect(throws: RunDayEditorError.missing) { try await unknown.save() }
}

@MainActor @Test func theRunEditorSavesTheTypeAndTheGoalOnlyOnSave() async throws {
    let setup = try await RunSetup()
    let model = await setup.model()
    model.setType(.long)
    model.setMinutes(75)
    #expect(model.hasChanges && model.day.name == "Sortie longue")
    #expect(try await setup.savedRun()?.runType == .easy, "Rien n'est écrit avant « Enregistrer »")
    try await model.save()
    let saved = try #require(try await setup.savedRun())
    #expect(saved.runType == .long && saved.runTargetMinutes == 75 && saved.runTargetKm == nil)
    #expect(saved.name == "Sortie longue" && saved.kind == .run)
    #expect(!model.hasChanges)
    let program = try #require(try await setup.fixture.programs.program(id: setup.program.id))
    #expect(program.days.map(\.id) == [setup.push, setup.run], "La course garde sa place dans le programme")
}

@MainActor @Test func switchingTheGoalKindKeepsEachValue() async throws {
    let setup = try await RunSetup()
    let model = await setup.model()
    model.setMinutes(45)
    model.setGoalKind(.distance)
    #expect(model.goal == .kilometres(5), "La distance de départ")
    model.setKilometres(12)
    model.setGoalKind(.none)
    #expect(model.goal == .none && model.goalKind == .none)
    model.setGoalKind(.distance)
    #expect(model.goal == .kilometres(12))
    model.setGoalKind(.duration)
    #expect(model.goal == .minutes(45))
    model.setMinutes(999)
    #expect(model.goal == .minutes(240), "La durée reste dans ses bornes")
    model.setGoalKind(.none)
    try await model.save()
    let saved = try #require(try await setup.savedRun())
    #expect(saved.runTargetMinutes == nil && saved.runTargetKm == nil)
}

@MainActor @Test func theRunEditorFailsWhenTheDayWasRemovedMeanwhile() async throws {
    let setup = try await RunSetup()
    let model = await setup.model()
    model.setType(.intervals)
    let program = try #require(try await setup.fixture.programs.program(id: setup.program.id))
    try await setup.fixture.programs.save(ProgramEditor.removeDay(id: setup.run, from: program, now: setup.fixture.now))
    await #expect(throws: RunDayEditorError.missing) { try await model.save() }
}

@MainActor @Test func theProgramEditorAddsAssignsAndRemovesARunDay() async throws {
    let fixture = TrainFixture()
    try await fixture.saveProfile()
    let model = ProgramEditorModel(environment: fixture.environment)
    await model.load()
    try await model.createEmpty(named: "Hybride")
    let push = try await model.addRoutine(named: "Push")
    let run = try await model.addRun()
    try await model.assign(push, to: .monday)
    try await model.assign(run, to: .wednesday)
    let id = try #require(model.program?.id)
    var saved = try #require(try await fixture.programs.program(id: id))
    let day = try #require(saved.days.last)
    #expect(day.id == run && day.kind == .run && day.runType == .easy && day.runTargetMinutes == 30)
    #expect(saved.weekLayout == [push, nil, run, nil, nil, nil, nil] && saved.sessionsPerWeek == 2)
    try await model.duplicate(run)
    try await model.remove(run)
    saved = try #require(try await fixture.programs.program(id: id))
    #expect(saved.days.map(\.name) == ["Push", "Sortie facile (copie)"])
    #expect(saved.weekLayout == [push, nil, nil, nil, nil, nil, nil] && saved.sessionsPerWeek == 1)
}
