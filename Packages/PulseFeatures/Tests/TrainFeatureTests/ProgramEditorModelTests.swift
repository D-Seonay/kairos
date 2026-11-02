import Foundation
import PulseDomain
import PulseServices
import Testing
@testable import TrainFeature

/// Un modèle chargé sur un profil enregistré et aucun programme.
@MainActor
private func loadedModel(_ fixture: TrainFixture) async throws -> ProgramEditorModel {
    try await fixture.saveProfile()
    let model = ProgramEditorModel(environment: fixture.environment)
    await model.load()
    return model
}

@MainActor @Test func buildingMatheoPPLSavesTheWeek() async throws {
    let fixture = TrainFixture()
    let model = try await loadedModel(fixture)
    try await model.createEmpty(named: "Mon PPL")
    let push = try await model.addRoutine(named: "Push")
    let pull = try await model.addRoutine(named: "Pull")
    let legs = try await model.addRoutine(named: "Legs")
    for (weekday, day) in [(Weekday.monday, push), (.tuesday, pull), (.wednesday, legs), (.thursday, push), (.friday, pull)] {
        try await model.assign(day, to: weekday)
    }
    let id = try #require(model.program?.id)
    let saved = try #require(try await fixture.programs.program(id: id))
    #expect(saved.name == "Mon PPL")
    #expect(saved.sessionsPerWeek == 5)
    #expect(saved.weekLayout == [push, pull, legs, push, pull, nil, nil])
    #expect(saved.days.map(\.name) == ["Push", "Pull", "Legs"])
    #expect(try await fixture.profiles.load()?.activeProgramID == saved.id)
}

@MainActor @Test func adoptingATemplateMakesItActive() async throws {
    let fixture = TrainFixture()
    let model = try await loadedModel(fixture)
    try await model.adopt("ppl-3")
    let program = try #require(model.program)
    #expect(program.templateID == "ppl-3")
    #expect(program.sessionsPerWeek == program.weekLayout.compactMap { $0 }.count)
    #expect(program.sessionsPerWeek > 0)
    #expect(try await fixture.profiles.load()?.activeProgramID == program.id)
    #expect(try await fixture.programs.program(id: program.id) == program)
}

@MainActor @Test func adoptingAnUnknownTemplateOrWithoutProfileFails() async throws {
    let fixture = TrainFixture()
    let withoutProfile = ProgramEditorModel(environment: fixture.environment)
    await #expect(throws: ProgramEditorError.noProfile) { try await withoutProfile.adopt("ppl-3") }
    await #expect(throws: ProgramEditorError.noProfile) { try await withoutProfile.createEmpty(named: "Mon PPL") }
    #expect(try await fixture.programs.programs(includeArchived: true).isEmpty)
    let model = try await loadedModel(fixture)
    await #expect(throws: ProgramEditorError.unknownTemplate) { try await model.adopt("nope") }
}

@MainActor @Test func removingTodaysRoutineLeavesNoOrphanInTheWeek() async throws {
    let fixture = TrainFixture()
    let model = try await loadedModel(fixture)
    try await model.createEmpty(named: "Mon PPL")
    let push = try await model.addRoutine(named: "Push")
    let pull = try await model.addRoutine(named: "Pull")
    try await model.assign(push, to: .monday)
    try await model.assign(pull, to: .tuesday)
    try await model.assign(push, to: .thursday)
    try await model.remove(push)
    let id = try #require(model.program?.id)
    let saved = try #require(try await fixture.programs.program(id: id))
    #expect(saved.days.map(\.name) == ["Pull"])
    #expect(saved.weekLayout == [nil, pull, nil, nil, nil, nil, nil])
    #expect(saved.sessionsPerWeek == 1)
    #expect(saved.days.map(\.order) == [0])
    // Le repos se pose aussi : mardi redevient « Repos ».
    try await model.assign(nil, to: .tuesday)
    #expect(model.program?.sessionsPerWeek == 0)
}

@MainActor @Test func switchingProgramsKeepsTheOthersListed() async throws {
    let fixture = TrainFixture()
    let model = try await loadedModel(fixture)
    try await model.createEmpty(named: "Premier")
    let first = try #require(model.program?.id)
    try await model.createEmpty(named: "Second")
    let second = try #require(model.program?.id)
    #expect(model.otherPrograms.map(\.id) == [first])
    try await model.activate(first)
    #expect(model.program?.id == first)
    #expect(model.otherPrograms.map(\.id) == [second])
    #expect(try await fixture.profiles.load()?.activeProgramID == first)
    await #expect(throws: ProgramEditorError.unknownProgram) { try await model.activate(UUID()) }
}

@MainActor @Test func archivingAnotherProgramHidesIt() async throws {
    let fixture = TrainFixture()
    let model = try await loadedModel(fixture)
    try await model.createEmpty(named: "Premier")
    let first = try #require(model.program?.id)
    try await model.createEmpty(named: "Second")
    try await model.archive(first)
    #expect(model.otherPrograms.isEmpty)
    #expect(try await fixture.programs.program(id: first)?.isArchived == true)
    #expect(model.program?.name == "Second")
}

@MainActor @Test func archivingTheActiveProgramClearsTheActiveOne() async throws {
    let fixture = TrainFixture()
    let model = try await loadedModel(fixture)
    try await model.createEmpty(named: "Premier")
    let id = try #require(model.program?.id)
    try await model.archive(id)
    #expect(model.program == nil)
    #expect(try await fixture.profiles.load()?.activeProgramID == nil)
}

@MainActor @Test func renameDuplicateAndFailuresWithoutProgram() async throws {
    let fixture = TrainFixture()
    let model = try await loadedModel(fixture)
    await #expect(throws: ProgramEditorError.noProgram) { try await model.addRoutine(named: "Push") }
    await #expect(throws: ProgramEditorError.noProgram) { try await model.rename("Nom") }
    try await model.createEmpty(named: "  ")
    #expect(model.program?.name == "Mon programme")
    try await model.rename("  Mon PPL  ")
    #expect(model.program?.name == "Mon PPL")
    let push = try await model.addRoutine(named: "Push")
    try await model.duplicate(push)
    #expect(model.program?.days.count == 2)
    #expect(model.program?.days.last?.name == "Push (copie)")
    let id = try #require(model.program?.id)
    #expect(try await fixture.programs.program(id: id) == model.program)
}

@MainActor @Test func theModelListsTheBundledTemplates() async throws {
    let fixture = TrainFixture()
    let model = try await loadedModel(fixture)
    #expect(model.templates.map(\.id).contains("ppl-3"))
    #expect(model.templates.count == fixture.environment.library.programTemplates.count)
    #expect(model.program == nil)
}
