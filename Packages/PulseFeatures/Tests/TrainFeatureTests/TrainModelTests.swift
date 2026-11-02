// swiftlint:disable force_unwrapping
import Foundation
import PulseContent
import PulseDomain
import PulseServices
import Testing
@testable import TrainFeature

/// Calendrier grégorien Europe/Paris en français ; lundi 2 novembre 2026, 9 h.
private enum TrainClock {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
        calendar.locale = Locale(identifier: "fr_FR")
        return calendar
    }()

    static func date(day: Int, hour: Int) -> Date {
        let start = calendar.date(from: DateComponents(year: 2026, month: 11, day: day))!
        return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: start)!
    }
}

/// Un dépôt de profil illisible.
private actor UnreadableProfileRepository: ProfileRepository {
    enum Failure: Error { case unreadable }

    func load() async throws -> UserProfile? { throw Failure.unreadable }
    func save(_ profile: UserProfile) async throws {}
    func delete(id: UUID) async throws {}
}

/// Les doublures de l'onglet Séance et l'environnement construit dessus.
@MainActor
private struct TrainFixture {
    let profiles: any ProfileRepository
    let programs = InMemoryProgramRepository()
    let recovery = InMemoryRecoveryRepository(calendar: TrainClock.calendar)
    let environment: TrainEnvironment
    let now: Date

    init(profiles: any ProfileRepository = InMemoryProfileRepository(), now: Date = TrainClock.date(day: 2, hour: 9)) {
        self.profiles = profiles
        self.now = now
        let library = ContentLibrary.bundled
        let calendar = TrainClock.calendar
        let workouts = InMemoryWorkoutRepository()
        let userExercises = InMemoryUserExerciseRepository()
        let personalRecords = InMemoryPersonalRecordRepository()
        let clock: @Sendable () -> Date = { now }
        let records = RecordsService(workouts: workouts, records: personalRecords, userExercises: userExercises,
                                     library: library, now: clock)
        let importer = HevyImporter(workouts: workouts, userExercises: userExercises, records: records,
                                    mappings: InMemoryHevyMappingStore(), library: library, calendar: calendar, now: clock)
        environment = TrainEnvironment(
            profiles: profiles, programs: programs, recovery: recovery, workouts: workouts, userExercises: userExercises,
            exerciseSettings: InMemoryExerciseSettingsRepository(), personalRecords: personalRecords, records: records,
            importer: importer, library: library, calendar: calendar, now: clock)
    }

    /// Enregistre `program` et le rend actif.
    func activate(_ program: Program) async throws {
        try await programs.save(program)
        try await profiles.save(UserProfile(firstName: "Mathéo", onboardingCompletedAt: now, activeProgramID: program.id,
                                            createdAt: now, updatedAt: now))
    }

    /// Un score « normal » enregistré pour aujourd'hui.
    func scoreToday(_ category: RecoveryCategory) async throws {
        try await recovery.save(DailyRecovery(
            day: TrainClock.calendar.startOfDay(for: now), score: 72, category: category, isEstimated: false,
            calibration: .ready, createdAt: now, updatedAt: now))
    }
}

/// PPL : Push lundi et jeudi, Pull mardi et vendredi, Legs mercredi ; `run` ajoute un footing le samedi.
private func pplProgram(withRun run: Bool = false) -> Program {
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
}
// swiftlint:enable force_unwrapping
