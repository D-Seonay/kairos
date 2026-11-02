import Foundation
import PulseDomain
import PulseServices
import Testing
@testable import TrainFeature

@MainActor @Test func launchingARoutineAppliesTodaysAdjustments() async throws {
    let fixture = TrainFixture()
    let program = pplProgram()
    try await fixture.activate(program)
    try await fixture.scoreToday(.moderateFatigue)
    let model = TrainModel(environment: fixture.environment)
    await model.refresh()
    let push = try #require(program.days.first { $0.name == "Push" })
    let launch = try #require(model.launch(routine: push.id))
    #expect(launch.title == "Push" && launch.programID == program.id)
    #expect(launch.plannedDay == push && launch.day != push)
    #expect(!launch.applied.isEmpty && launch.refused.isEmpty)
    #expect(!launch.policy.allowsIncrease)
}

@MainActor @Test func launchingARoutineWithoutScoreKeepsItAsPlanned() async throws {
    let fixture = TrainFixture()
    let program = pplProgram()
    try await fixture.activate(program)
    let model = TrainModel(environment: fixture.environment)
    await model.refresh()
    let pull = try #require(program.days.first { $0.name == "Pull" })
    let launch = try #require(model.launch(routine: pull.id))
    #expect(launch.day == pull && launch.applied.isEmpty && launch.refused.isEmpty)
    #expect(launch.policy.allowsIncrease)
}

@MainActor @Test func launchingARoutineHonoursTheOriginalSessionChoice() async throws {
    let fixture = TrainFixture()
    let program = pplProgram()
    try await fixture.activate(program)
    try await fixture.scoreToday(.moderateFatigue, originalChosen: true)
    let model = TrainModel(environment: fixture.environment)
    await model.refresh()
    let push = try #require(program.days.first { $0.name == "Push" })
    let launch = try #require(model.launch(routine: push.id))
    #expect(launch.day == push && launch.applied.isEmpty && !launch.refused.isEmpty)
}

@MainActor @Test func launchingAnUnknownRoutineOrARunDoesNothing() async throws {
    let fixture = TrainFixture()
    let program = pplProgram(withRun: true)
    try await fixture.activate(program)
    let model = TrainModel(environment: fixture.environment)
    await model.refresh()
    let footing = try #require(program.days.first { $0.kind == .run })
    #expect(model.launch(routine: UUID()) == nil)
    #expect(model.launch(routine: footing.id) == nil)
}

@MainActor @Test func theStrengthTileLaunchesTodaysSession() async throws {
    let monday = TrainFixture()
    try await monday.activate(pplProgram())
    try await monday.scoreToday(.moderateFatigue)
    let model = TrainModel(environment: monday.environment)
    await model.refresh()
    let launch = try #require(model.launchToday())
    #expect(launch.title == "Push" && !launch.applied.isEmpty)

    let saturday = TrainFixture(now: TrainClock.date(day: 7, hour: 9))
    try await saturday.activate(pplProgram())
    let restDay = TrainModel(environment: saturday.environment)
    await restDay.refresh()
    #expect(restDay.launchToday() == nil)

    let run = TrainFixture(now: TrainClock.date(day: 7, hour: 9))
    try await run.activate(pplProgram(withRun: true))
    let runDay = TrainModel(environment: run.environment)
    await runDay.refresh()
    #expect(runDay.launchToday() == nil)
}

@MainActor @Test func freeSessionUsesTodaysPolicy() async throws {
    let tired = TrainFixture()
    try await tired.activate(pplProgram())
    try await tired.scoreToday(.moderateFatigue)
    let tiredModel = TrainModel(environment: tired.environment)
    await tiredModel.refresh()
    let free = tiredModel.freeLaunch()
    #expect(free.title == "Séance libre" && free.day == nil && free.programID == nil)
    #expect(!free.policy.allowsIncrease)

    let rested = TrainFixture()
    try await rested.activate(pplProgram())
    try await rested.scoreToday(.normal)
    let restedModel = TrainModel(environment: rested.environment)
    await restedModel.refresh()
    #expect(restedModel.freeLaunch().policy.allowsIncrease)
}

@MainActor @Test func activeSessionIsReported() async throws {
    let fixture = TrainFixture()
    try await fixture.activate(pplProgram())
    let model = TrainModel(environment: fixture.environment)
    await model.refresh()
    #expect(model.activeSessionTitle == nil)

    _ = try await fixture.activeSession.start(model.freeLaunch())
    await model.refresh()
    #expect(model.activeSessionTitle == "Séance libre")
}
