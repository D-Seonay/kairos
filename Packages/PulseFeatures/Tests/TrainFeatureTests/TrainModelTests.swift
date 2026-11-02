// swiftlint:disable force_unwrapping
import Foundation
import PulseContent
import PulseDomain
import PulseServices
import Testing
@testable import TrainFeature

/// Un dépôt de profil illisible.
private actor UnreadableProfileRepository: ProfileRepository {
    enum Failure: Error { case unreadable }

    func load() async throws -> UserProfile? { throw Failure.unreadable }
    func save(_ profile: UserProfile) async throws {}
    func delete(id: UUID) async throws {}
}

/// PPL : Push lundi et jeudi, Pull mardi et vendredi, Legs mercredi ; `run` ajoute un footing le samedi.
func pplProgram(withRun run: Bool = false) -> Program {
    func strength(_ order: Int, _ name: String, _ exerciseID: String) -> RoutineDay {
        RoutineDay(order: order, name: name, kind: .strength, exercises: [
            RoutineExercise(order: 0, exercise: .content(id: exerciseID), sets: 3, repsMin: 8, repsMax: 10,
                            targetRPE: 8, restSeconds: 120),
            RoutineExercise(order: 1, exercise: .content(id: exerciseID), sets: 3, repsMin: 10, repsMax: 12,
                            targetRPE: 7, restSeconds: 90)
        ])
    }
    let push = strength(0, "Push", "bench-press-barbell")
    let pull = strength(1, "Pull", "bench-press-barbell")
    let legs = strength(2, "Legs", "bench-press-barbell")
    let footing = RoutineDay(order: 3, name: "Footing", kind: .run, runType: .easy, runTargetMinutes: 40)
    let days = run ? [push, pull, legs, footing] : [push, pull, legs]
    let layout: [UUID?] = [push.id, pull.id, legs.id, push.id, pull.id, run ? footing.id : nil, nil]
    let created = TrainClock.date(day: 1, hour: 9)
    return Program(name: "PPL", sessionsPerWeek: run ? 6 : 5, weekLayout: layout, days: days, createdAt: created, updatedAt: created)
}

@MainActor @Test func trainModelListsRoutinesWithTheirWeekdays() async throws {
    let fixture = TrainFixture()
    try await fixture.activate(pplProgram())
    try await fixture.scoreToday(.normal)
    let model = TrainModel(environment: fixture.environment)
    await model.refresh()
    #expect(model.routines.map(\.day.name) == ["Push", "Pull", "Legs"])
    #expect(model.routines[0].weekdays == [.monday, .thursday])
    #expect(model.routines[1].weekdays == [.tuesday, .friday])
    #expect(model.routines[2].weekdays == [.wednesday])
    #expect(model.routines[0].exerciseCount == 2)
    // 6 séries : 6 × 45 s d'effort, 3 × 120 s et 2 × 90 s de repos (aucun après la dernière série) = 810 s, soit 15 min.
    #expect(model.routines[0].estimatedMinutes == 15)
    #expect(model.today?.status == .adjusted)
    #expect(model.today?.originalDay?.name == "Push")
    #expect(model.program?.name == "PPL")
    #expect(model.errorMessage == nil)
}

@MainActor @Test func trainModelWithoutScoreKeepsThePlannedSession() async throws {
    let fixture = TrainFixture()
    try await fixture.activate(pplProgram())
    let model = TrainModel(environment: fixture.environment)
    await model.refresh()
    #expect(model.today?.status == .planned)
    #expect(model.today?.originalDay?.name == "Push")
}

@MainActor @Test func trainModelWithoutProgramShowsNoRoutines() async throws {
    let fixture = TrainFixture()
    try await fixture.profiles.save(UserProfile(onboardingCompletedAt: fixture.now, createdAt: fixture.now, updatedAt: fixture.now))
    let model = TrainModel(environment: fixture.environment)
    await model.refresh()
    #expect(model.program == nil)
    #expect(model.routines.isEmpty)
    #expect(model.today?.plannedDay == .noProgram)
    #expect(model.nextRun == nil)
    #expect(model.errorMessage == nil)
}

@MainActor @Test func trainModelFindsTheNextRun() async throws {
    let fixture = TrainFixture()
    try await fixture.activate(pplProgram(withRun: true))
    let model = TrainModel(environment: fixture.environment)
    await model.refresh()
    #expect(model.nextRun?.day.name == "Footing")
    #expect(model.nextRun?.weekday == .saturday)
    #expect(model.routines.last?.estimatedMinutes == 40)
}

@MainActor @Test func trainModelShowsTodaysRunAsTheNextRun() async throws {
    let fixture = TrainFixture(now: TrainClock.date(day: 7, hour: 9))
    try await fixture.activate(pplProgram(withRun: true))
    let model = TrainModel(environment: fixture.environment)
    await model.refresh()
    #expect(model.nextRun?.weekday == .saturday)
    #expect(model.today?.plannedDay == .run(model.nextRun!.day))
}

@MainActor @Test func trainModelReportsAReadFailure() async {
    let fixture = TrainFixture(profiles: UnreadableProfileRepository())
    let model = TrainModel(environment: fixture.environment)
    await model.refresh()
    #expect(model.errorMessage != nil)
    #expect(model.routines.isEmpty)
    #expect(model.today == nil)
    #expect(!model.showsNoProgram)
}
// swiftlint:enable force_unwrapping

@MainActor @Test func trainModelSaysWhenThereIsNoProgram() async throws {
    let fixture = TrainFixture()
    try await fixture.profiles.save(UserProfile(onboardingCompletedAt: fixture.now, createdAt: fixture.now, updatedAt: fixture.now))
    let model = TrainModel(environment: fixture.environment)
    await model.refresh()
    #expect(model.showsNoProgram)
    #expect(model.strengthSubtitle == "Aucun programme actif")
}

/// Samedi et dimanche sont des jours de repos : la tuile annonce la prochaine séance, Push le lundi.
@MainActor @Test func trainModelNamesTheNextSessionOnARestDay() async throws {
    let saturday = TrainFixture(now: TrainClock.date(day: 7, hour: 9))
    try await saturday.activate(pplProgram())
    let model = TrainModel(environment: saturday.environment)
    await model.refresh()
    #expect(model.strengthSubtitle == "Repos · prochaine : Push, lundi")

    let sunday = TrainFixture(now: TrainClock.date(day: 8, hour: 9))
    try await sunday.activate(pplProgram())
    let next = TrainModel(environment: sunday.environment)
    await next.refresh()
    #expect(next.strengthSubtitle == "Repos · prochaine : Push, demain")
}

@MainActor @Test func trainModelSummarisesTodaysStrengthSession() async throws {
    let fixture = TrainFixture()
    try await fixture.activate(pplProgram())
    let model = TrainModel(environment: fixture.environment)
    await model.refresh()
    #expect(model.strengthSubtitle == "Push · ~ 15 min")
}

@MainActor @Test func trainModelAddsARoutineToTheActiveProgram() async throws {
    let fixture = TrainFixture()
    let now = fixture.now
    try await fixture.activate(ProgramEditor.emptyProgram(name: "PPL", now: now))
    let model = TrainModel(environment: fixture.environment)
    await model.refresh()
    #expect(model.routines.isEmpty)
    let id = try await model.addRoutine(named: "Nouvelle routine")
    #expect(model.routines.map(\.day.id) == [id])
    #expect(model.routines.first?.day.name == "Nouvelle routine")
    #expect(model.routines.first?.weekdays.isEmpty == true)
}

@MainActor @Test func trainModelCannotAddARoutineWithoutAProgram() async throws {
    let fixture = TrainFixture()
    let model = TrainModel(environment: fixture.environment)
    await #expect(throws: ProgramEditorError.noProgram) { try await model.addRoutine(named: "Push") }
}
