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

@MainActor @Test func trainRunLaunchIsTodayPlannedRunOrFree() async throws {
    // Samedi : le footing du programme est la course du jour, et sous une fatigue modérée le fractionné devient une sortie facile.
    let saturday = TrainFixture(now: TrainClock.date(day: 7, hour: 9))
    let program = pplProgram(withRun: true)
    try await saturday.activate(program)
    let planned = TrainModel(environment: saturday.environment)
    await planned.refresh()
    let footing = try #require(program.days.first { $0.kind == .run })
    let launch = planned.runLaunch()
    #expect(launch.title == "Sortie facile" && launch.programID == program.id && launch.routineDayID == footing.id)
    #expect(launch.targetMinutes == 40 && launch.adjustmentNote == nil)

    let intervals = RoutineDay(order: 3, name: "Fractionné", kind: .run, runType: .intervals, runTargetMinutes: 30)
    var tough = pplProgram(withRun: true)
    tough.days = tough.days.filter { $0.kind == .strength } + [intervals]
    tough.weekLayout[5] = intervals.id
    let tired = TrainFixture(now: TrainClock.date(day: 7, hour: 9))
    try await tired.activate(tough)
    try await tired.scoreToday(.moderateFatigue)
    let adjustedModel = TrainModel(environment: tired.environment)
    await adjustedModel.refresh()
    #expect(adjustedModel.runLaunch().runType == .easy)
    #expect(adjustedModel.runLaunch().adjustmentNote == "au lieu du fractionné")

    // Un autre jour que celui de la course, ou sans programme : une course libre.
    let monday = TrainFixture()
    try await monday.activate(program)
    let other = TrainModel(environment: monday.environment)
    await other.refresh()
    #expect(other.nextRun != nil)
    #expect(other.runLaunch() == RunLaunch.free())
    #expect(TrainModel(environment: monday.environment).runLaunch() == RunLaunch.free())
}

@MainActor @Test func aRunRoutineLaunchesItsOwnRunAdjustedOnlyOnItsDay() async throws {
    let intervals = RoutineDay(order: 3, name: "Fractionné", kind: .run, runType: .intervals, runTargetMinutes: 30)
    var tough = pplProgram(withRun: true)
    tough.days = tough.days.filter { $0.kind == .strength } + [intervals]
    tough.weekLayout[5] = intervals.id

    // Un autre jour que celui de la course : la course telle qu'au programme, sans l'ajustement du jour.
    let monday = TrainFixture()
    try await monday.activate(tough)
    try await monday.scoreToday(.moderateFatigue)
    let other = TrainModel(environment: monday.environment)
    await other.refresh()
    let planned = try #require(other.runLaunch(routine: intervals.id))
    #expect(planned.routineDayID == intervals.id && planned.programID == tough.id)
    #expect(planned.runType == .intervals && planned.targetMinutes == 30 && planned.adjustmentNote == nil)

    // Le jour de la course : ajustée comme sur l'accueil.
    let saturday = TrainFixture(now: TrainClock.date(day: 7, hour: 9))
    try await saturday.activate(tough)
    try await saturday.scoreToday(.moderateFatigue)
    let today = TrainModel(environment: saturday.environment)
    await today.refresh()
    #expect(today.runLaunch(routine: intervals.id)?.runType == .easy)

    // Une routine de musculation ou un jour inconnu ne se lancent pas en course.
    let push = try #require(tough.days.first { $0.kind == .strength })
    #expect(other.runLaunch(routine: push.id) == nil)
    #expect(other.runLaunch(routine: UUID()) == nil)
}

/// Une ligne de la semaine datée d'aujourd'hui (samedi 7 novembre) : `routineDayID` nul pour un jour de repos.
private func override(_ routineDay: RoutineDay?, for program: Program) -> ScheduledDay {
    let date = TrainClock.date(day: 7, hour: 0)
    return ScheduledDay(date: date, programID: program.id, routineDayID: routineDay?.id, title: routineDay?.name ?? "Repos",
                        kind: routineDay?.kind == .run ? .run : routineDay == nil ? .rest : .strength, status: .planned,
                        createdAt: date, updatedAt: date)
}

/// Le bouton « Courir » dit ce qu'il lance, d'après la semaine datée et non la semaine type.
@MainActor @Test func runStartLabelFollowsTheDatedWeek() async throws {
    let program = pplProgram(withRun: true)

    // La semaine type place le footing aujourd'hui, mais il a été déplacé : course libre, et le libellé le dit.
    let moved = TrainFixture(now: TrainClock.date(day: 7, hour: 9))
    try await moved.activate(program)
    try await moved.scheduled.save(override(nil, for: program))
    let movedModel = TrainModel(environment: moved.environment)
    await movedModel.refresh()
    // La tuile ne dit pas « aujourd'hui » : la prochaine course est celle de samedi prochain, dans 7 jours.
    #expect(movedModel.nextRun?.weekday == .saturday && movedModel.nextRunDaysAhead == 7)
    #expect(movedModel.runSubtitle.hasSuffix(" · prévue samedi prochain"))
    #expect(movedModel.runLaunch() == RunLaunch.free() && !movedModel.runLaunchIsPlanned)
    #expect(movedModel.runStartLabel == "Lancer une course libre")

    // L'inverse : un lundi sans course dans la semaine type, mais la semaine datée y place le footing.
    let monday = TrainFixture()
    try await monday.activate(program)
    let footing = try #require(program.days.first { $0.kind == .run })
    let date = TrainClock.date(day: 2, hour: 0)
    try await monday.scheduled.save(ScheduledDay(
        date: date, programID: program.id, routineDayID: footing.id, title: footing.name, kind: .run, status: .planned,
        createdAt: date, updatedAt: date))
    let placed = TrainModel(environment: monday.environment)
    await placed.refresh()
    #expect(placed.daysUntil(.saturday) == 5)
    // La tuile suit la semaine datée, comme la carte du jour : la course est aujourd'hui.
    #expect(placed.nextRun?.weekday == .monday && placed.nextRunDaysAhead == 0)
    #expect(placed.runSubtitle.hasSuffix(" · aujourd'hui"))
    #expect(placed.runLaunch().routineDayID == footing.id && placed.runLaunchIsPlanned)
    #expect(placed.runStartLabel == "Lancer la course du jour")

    // Sans override, la course du jour de la semaine type : le libellé reste « la course du jour ».
    let plain = TrainFixture(now: TrainClock.date(day: 7, hour: 9))
    try await plain.activate(program)
    let plainModel = TrainModel(environment: plain.environment)
    await plainModel.refresh()
    #expect(plainModel.runStartLabel == "Lancer la course du jour")
}
