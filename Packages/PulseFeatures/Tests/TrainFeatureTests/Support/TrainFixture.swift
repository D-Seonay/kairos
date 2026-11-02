// swiftlint:disable force_unwrapping
import Foundation
import PulseContent
import PulseDomain
import PulseServices
@testable import TrainFeature

/// Calendrier grégorien Europe/Paris en français ; lundi 2 novembre 2026, 9 h.
enum TrainClock {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
        calendar.locale = Locale(identifier: "fr_FR")
        return calendar
    }()

    /// Un jour de novembre 2026.
    static func date(day: Int, hour: Int) -> Date {
        date(month: 11, day: day, hour: hour)
    }

    static func date(month: Int, day: Int, hour: Int) -> Date {
        let start = calendar.date(from: DateComponents(year: 2026, month: month, day: day))!
        return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: start)!
    }
}

/// Une série à enregistrer dans une séance de test.
struct LoggedSet {
    var weightKg: Double
    var reps: Int
    var type: SetType = .working
    var rpe: Double?
}

/// Les doublures de l'onglet Séance et l'environnement construit dessus.
@MainActor
struct TrainFixture {
    let profiles: any ProfileRepository
    let programs = InMemoryProgramRepository()
    let recovery = InMemoryRecoveryRepository(calendar: TrainClock.calendar)
    let environment: TrainEnvironment
    let activeSession: ActiveSessionService
    let now: Date

    init(profiles: any ProfileRepository = InMemoryProfileRepository(), now: Date = TrainClock.date(day: 2, hour: 9),
         exerciseSettings: any ExerciseSettingsRepository = InMemoryExerciseSettingsRepository()) {
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
        activeSession = ActiveSessionService(
            store: InMemoryActiveSessionStore(), workouts: workouts, profiles: profiles, settings: exerciseSettings,
            userExercises: userExercises, records: records, library: library, restNotifier: StubRestTimerNotifier(),
            activity: StubSessionActivityController(), calendar: calendar, now: clock)
        environment = TrainEnvironment(
            profiles: profiles, programs: programs, recovery: recovery, workouts: workouts, userExercises: userExercises,
            exerciseSettings: exerciseSettings, personalRecords: personalRecords, records: records,
            importer: importer, library: library, activeSession: activeSession, calendar: calendar, now: clock)
    }

    /// Enregistre `program` et le rend actif.
    func activate(_ program: Program) async throws {
        try await programs.save(program)
        try await profiles.save(UserProfile(firstName: "Mathéo", onboardingCompletedAt: now, activeProgramID: program.id,
                                            createdAt: now, updatedAt: now))
    }

    /// Un score enregistré pour aujourd'hui, avec « Séance d'origine » choisie si `originalChosen`.
    func scoreToday(_ category: RecoveryCategory, originalChosen: Bool? = nil) async throws {
        try await recovery.save(DailyRecovery(
            day: TrainClock.calendar.startOfDay(for: now), score: 72, category: category, isEstimated: false,
            calibration: .ready, originalSessionChosen: originalChosen, createdAt: now, updatedAt: now))
    }

    /// Enregistre un profil dont les zones douloureuses sont `painAreas`.
    func saveProfile(painAreas: [PainArea] = []) async throws {
        try await profiles.save(UserProfile(firstName: "Mathéo", painAreas: painAreas, onboardingCompletedAt: now,
                                            createdAt: now, updatedAt: now))
    }

    /// Enregistre une séance terminée de musculation avec ces séries d'un seul exercice, dans l'ordre ; rend la séance.
    @discardableResult
    func log(_ exercise: ExerciseReference = .content(id: "bench-press-barbell"), on date: Date, sets: [LoggedSet],
             status: SessionStatus = .completed, title: String = "Séance",
             source: SessionSource = .pulse) async throws -> WorkoutSession {
        let workoutSets = sets.enumerated().map { index, set in
            WorkoutSet(order: index, exercise: exercise, exerciseName: "Exercice", setType: set.type,
                       actualWeightKg: set.weightKg, actualReps: set.reps, rpe: set.rpe, completedAt: date)
        }
        let session = WorkoutSession(startedAt: date, endedAt: date.addingTimeInterval(3_600), kind: .strength, source: source,
                                     status: status, title: title, sets: workoutSets, createdAt: date, updatedAt: date)
        try await environment.workouts.save(session)
        return session
    }

    /// Enregistre l'exercice perso `exercise`.
    func store(_ exercise: UserExercise) async throws {
        try await environment.userExercises.save(exercise)
    }
}
// swiftlint:enable force_unwrapping
