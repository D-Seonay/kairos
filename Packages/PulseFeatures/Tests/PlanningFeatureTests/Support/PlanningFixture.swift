// swiftlint:disable force_unwrapping
import Foundation
import PlanningFeature
import PulseContent
import PulseDomain
import PulseServices
import TrainFeature

/// Calendrier grégorien Europe/Paris en français.
enum PlanningClock {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
        calendar.locale = Locale(identifier: "fr_FR")
        return calendar
    }()

    /// Un jour de novembre 2026.
    static func date(day: Int, hour: Int = 0, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute))!
    }
}

/// Les doublures de l'onglet Planning, le mercredi 18 novembre 2026 à midi : Push Pull Legs, course le jeudi, Push le vendredi.
@MainActor
struct PlanningFixture {
    static let push = RoutineDay(order: 0, name: "Push", kind: .strength)
    static let pull = RoutineDay(order: 1, name: "Pull", kind: .strength)
    static let legs = RoutineDay(order: 2, name: "Legs", kind: .strength)
    static let run = RoutineDay(order: 3, name: "Endurance", kind: .run, runType: .easy, runTargetMinutes: 45)

    let profiles = InMemoryProfileRepository()
    let programs = InMemoryProgramRepository()
    let workouts = InMemoryWorkoutRepository()
    let scheduled = InMemoryScheduledDayRepository()
    let environment: PlanningEnvironment
    let now: Date
    let program: Program

    init(now: Date = PlanningClock.date(day: 18, hour: 12)) {
        self.now = now
        let calendar = PlanningClock.calendar
        let library = ContentLibrary.bundled
        let clock: @Sendable () -> Date = { now }
        let userExercises = InMemoryUserExerciseRepository()
        let personalRecords = InMemoryPersonalRecordRepository()
        let settings = InMemoryExerciseSettingsRepository()
        let records = RecordsService(workouts: workouts, records: personalRecords, userExercises: userExercises, library: library,
                                     now: clock)
        let importer = HevyImporter(workouts: workouts, userExercises: userExercises, records: records,
                                    mappings: InMemoryHevyMappingStore(), library: library, calendar: calendar, now: clock)
        let activeSession = ActiveSessionService(
            store: InMemoryActiveSessionStore(), workouts: workouts, profiles: profiles, settings: settings,
            userExercises: userExercises, records: records, library: library, restNotifier: StubRestTimerNotifier(),
            activity: StubSessionActivityController(), calendar: calendar, now: clock)
        let train = TrainEnvironment(
            profiles: profiles, programs: programs, recovery: InMemoryRecoveryRepository(calendar: calendar), workouts: workouts,
            userExercises: userExercises, exerciseSettings: settings, personalRecords: personalRecords, records: records,
            importer: importer, library: library, activeSession: activeSession, calendar: calendar, now: clock)
        let service = PlanningService(profiles: profiles, programs: programs, workouts: workouts, scheduledDays: scheduled,
                                      calendar: calendar, now: clock)
        environment = PlanningEnvironment(service: service, train: train, calendar: calendar, now: clock)
        let created = PlanningClock.date(day: 1)
        program = Program(name: "PPL + course", sessionsPerWeek: 5,
                          weekLayout: [Self.push.id, Self.pull.id, Self.legs.id, Self.run.id, Self.push.id, nil, nil],
                          days: [Self.push, Self.pull, Self.legs, Self.run], createdAt: created, updatedAt: created)
    }

    func activate() async throws {
        try await programs.save(program)
        try await profiles.save(UserProfile(restWeekdays: [.sunday], onboardingCompletedAt: PlanningClock.date(day: 1),
                                            activeProgramID: program.id))
    }

    @discardableResult
    func log(day: Int, hour: Int = 18, kind: SessionKind = .strength, tonnage: Double = 0, meters: Double? = nil,
             source: SessionSource = .pulse) async throws -> WorkoutSession {
        let start = PlanningClock.date(day: day, hour: hour)
        let session = WorkoutSession(startedAt: start, endedAt: start.addingTimeInterval(2_700), kind: kind, source: source,
                                     status: .completed, title: kind == .run ? "Course" : "Push", tonnageKg: tonnage,
                                     durationMinutes: 45, distanceMeters: meters, averageHeartRate: kind == .run ? 150 : nil,
                                     estimatedRPE: kind == .run ? 7 : nil, createdAt: start, updatedAt: start)
        try await workouts.save(session)
        return session
    }
}
// swiftlint:enable force_unwrapping
