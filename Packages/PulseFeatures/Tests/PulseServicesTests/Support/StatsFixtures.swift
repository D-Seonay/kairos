import Foundation
import PulseContent
import PulseDomain
import PulseRecoveryEngine
import PulseServices

/// Les dépôts en mémoire d'un test de `StatsService`.
struct StatsRepositories: Sendable {
    let profiles = InMemoryProfileRepository()
    let programs = InMemoryProgramRepository()
    let workouts = InMemoryWorkoutRepository()
    let recoveries = InMemoryRecoveryRepository(calendar: TestClock.calendar)
    let records = InMemoryPersonalRecordRepository()
    let userExercises = InMemoryUserExerciseRepository()

    func service(now: Date = StatsFixtures.now) -> StatsService {
        StatsService(profiles: profiles, programs: programs, workouts: workouts, recoveries: recoveries, records: records,
                     userExercises: userExercises, library: .bundled, calendar: TestClock.calendar, now: { now })
    }
}

extension StatsRepositories {
    func profileService(now: Date = StatsFixtures.now) -> ProfileService {
        ProfileService(profiles: profiles, programs: programs, workouts: workouts, recoveries: recoveries, records: records,
                       userExercises: userExercises, library: .bundled, calendar: TestClock.calendar, now: { now })
    }
}

/// Un exercice d'une séance type : la charge de départ et son gain par semaine.
struct StatsLift {
    var id: String
    var name: String
    var startKg: Double
    var weeklyKg: Double
    var reps: Int
}

/// Vingt semaines d'entraînement qui finissent le vendredi 20 novembre 2026 : PPL lundi, mardi, mercredi, Push jeudi, course
/// le samedi avec fréquence cardiaque, un vélo par mois, une semaine manquée (la 12e), 8 séances de musculation importées de
/// Hevy au début (les semaines 1 et 2), un score par nuit avec des trous.
///
/// L'objectif hebdomadaire du programme est de 4 : les semaines 1 à 11 réussissent, la 12e est manquée, les semaines 13 à 20
/// réussissent (la semaine en cours dès le jeudi). La meilleure série (11 semaines, 1 à 11) diffère donc de la série en cours (8).
enum StatsFixtures {
    static let now = TestClock.date("2026-11-20T12:00")
    static let weeks = 20
    /// Le programme : 4 séances de musculation par semaine, la course du samedi en plus.
    static let weeklyTarget = 4
    static let missedWeek = 12
    /// Les musculations des semaines 1 et 2 viennent de Hevy : 8 séances.
    static let hevyWeeks = 2

    private static var calendar: Calendar { TestClock.calendar }

    static let push = [
        StatsLift(id: "bench-press-barbell", name: "Développé couché", startKg: 70, weeklyKg: 1.25, reps: 5),
        StatsLift(id: "overhead-press-barbell", name: "Développé militaire", startKg: 40, weeklyKg: 0.625, reps: 6),
        StatsLift(id: "lateral-raise-dumbbell", name: "Élévations latérales", startKg: 8, weeklyKg: 0.25, reps: 12),
        StatsLift(id: "triceps-pushdown-cable", name: "Extensions triceps", startKg: 25, weeklyKg: 0.5, reps: 12)
    ]
    static let pull = [
        StatsLift(id: "deadlift-barbell", name: "Soulevé de terre", startKg: 110, weeklyKg: 2.5, reps: 5),
        StatsLift(id: "barbell-row", name: "Rowing barre", startKg: 60, weeklyKg: 1.25, reps: 8),
        StatsLift(id: "seated-cable-row", name: "Tirage poitrine assis", startKg: 55, weeklyKg: 1, reps: 10),
        StatsLift(id: "barbell-curl", name: "Curl barre", startKg: 25, weeklyKg: 0.5, reps: 10)
    ]
    static let legs = [
        StatsLift(id: "back-squat-barbell", name: "Squat", startKg: 90, weeklyKg: 2.5, reps: 5),
        StatsLift(id: "romanian-deadlift-barbell", name: "Soulevé de terre roumain", startKg: 80, weeklyKg: 1.25, reps: 8),
        StatsLift(id: "leg-press-machine", name: "Presse à cuisses", startKg: 140, weeklyKg: 2.5, reps: 10),
        StatsLift(id: "standing-calf-raise-machine", name: "Mollets debout", startKg: 60, weeklyKg: 1, reps: 12)
    ]

    /// Le lundi de la semaine `week` (1 à `weeks`), à minuit ; la dernière est la semaine du 16 novembre.
    static func monday(ofWeek week: Int) -> Date {
        let current = WeekSchedule.weekStart(of: now, calendar: calendar)
        return calendar.date(byAdding: .weekOfYear, value: week - weeks, to: current) ?? current
    }

    static func day(_ offset: Int, ofWeek week: Int, hour: Int = 18) -> Date {
        let day = calendar.date(byAdding: .day, value: offset, to: monday(ofWeek: week)) ?? monday(ofWeek: week)
        return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day) ?? day
    }

    // MARK: - Séances

    /// 20 séries : 1 d'échauffement et 4 de travail pour le premier exercice, 5 de travail pour chacun des trois autres.
    static func strengthSession(_ lifts: [StatsLift], title: String, start: Date, week: Int, source: SessionSource = .pulse,
                                programID: UUID? = nil) -> WorkoutSession {
        var sets: [WorkoutSet] = []
        for (index, lift) in lifts.enumerated() {
            let kg = ((lift.startKg + Double(week) * lift.weeklyKg) / 0.625).rounded() * 0.625
            let working = index == 0 ? 4 : 5
            if index == 0 {
                sets.append(WorkoutSet(order: sets.count, exercise: .content(id: lift.id), exerciseName: lift.name,
                                       setType: .warmup, actualWeightKg: (kg / 2 / 2.5).rounded() * 2.5, actualReps: 8))
            }
            for _ in 0..<working {
                sets.append(WorkoutSet(order: sets.count, exercise: .content(id: lift.id), exerciseName: lift.name,
                                       setType: .working, actualWeightKg: kg, actualReps: lift.reps, rpe: 8,
                                       completedAt: start.addingTimeInterval(Double(sets.count) * 150)))
            }
        }
        let directory = ExerciseDirectory(library: .bundled, userExercises: [])
        return WorkoutSession(startedAt: start, endedAt: start.addingTimeInterval(3_600), kind: .strength, source: source,
                              status: .completed, programID: programID, title: title, overallRPE: 7.5,
                              tonnageKg: SessionTonnage.kilograms(of: sets, loadKind: directory.loadKind(of:)),
                              durationMinutes: 60, sets: sets, createdAt: start, updatedAt: start)
    }

    /// Une course d'environ 8 km en 45 minutes, avec la fréquence cardiaque moyenne d'Apple Santé.
    static func run(start: Date) -> WorkoutSession {
        WorkoutSession(startedAt: start, endedAt: start.addingTimeInterval(2_700), kind: .run, source: .appleHealth,
                       status: .completed, title: "Course", durationMinutes: 45, distanceMeters: 8_000, averageHeartRate: 152,
                       estimatedRPE: 6, healthKitUUID: UUID().uuidString, createdAt: start, updatedAt: start)
    }

    static func ride(start: Date) -> WorkoutSession {
        WorkoutSession(startedAt: start, endedAt: start.addingTimeInterval(2_400), kind: .ride, source: .appleHealth,
                       status: .completed, title: "Vélo", durationMinutes: 40, distanceMeters: 18_000, averageHeartRate: 128,
                       estimatedRPE: 5, healthKitUUID: UUID().uuidString, createdAt: start, updatedAt: start)
    }

    static func sessions(programID: UUID) -> [WorkoutSession] {
        var sessions: [WorkoutSession] = []
        for week in 1...weeks where week != missedWeek {
            let hevy = week <= hevyWeeks
            let source: SessionSource = hevy ? .hevy : .pulse
            func strength(_ lifts: [StatsLift], _ title: String, offset: Int) {
                let start = day(offset, ofWeek: week)
                guard start < now else { return }
                sessions.append(strengthSession(lifts, title: title, start: start, week: week, source: source,
                                                programID: hevy ? nil : programID))
            }
            strength(push, "Push", offset: 0)
            strength(pull, "Pull", offset: 1)
            strength(legs, "Legs", offset: 2)
            strength(push, "Push", offset: 3)
            sessions.append(run(start: day(5, ofWeek: week, hour: 10)))
            if week % 4 == 2 { sessions.append(ride(start: day(6, ofWeek: week, hour: 10))) }
        }
        return sessions
    }

    // MARK: - Scores

    /// Un score par nuit depuis le lundi de la première semaine : une nuit sur 10 absente, une sur 15 estimée par check-in.
    static func recoveries() -> [DailyRecovery] {
        let first = monday(ofWeek: 1)
        let nights = calendar.dateComponents([.day], from: first, to: calendar.startOfDay(for: now)).day ?? 0
        return (0...nights).compactMap { index in
            guard index % 10 != 9, let day = calendar.date(byAdding: .day, value: index, to: first) else { return nil }
            let wave = sin(Double(index) * 0.7)
            let score = (74 + 18 * wave).rounded()
            let estimated = index % 15 == 14
            return DailyRecovery(
                day: day, score: score, category: RecoveryCategory(score: score), isEstimated: estimated,
                hrvScore: estimated ? nil : score, restingHeartRateScore: estimated ? nil : score,
                sleepScore: estimated ? nil : score,
                sdnnMs: estimated ? nil : (58 + 9 * wave).rounded(), sdnnBaselineMs: estimated ? nil : 58,
                restingHeartRate: estimated ? nil : (52 - 2 * wave).rounded(), restingHeartRateBaseline: estimated ? nil : 52,
                asleepMinutes: estimated ? nil : 430 + Int(30 * wave), deepMinutes: estimated ? nil : 75 + Int(12 * wave),
                calibration: .ready, createdAt: day, updatedAt: day)
        }
    }

    // MARK: - Dépôts

    static func program() -> Program {
        let created = monday(ofWeek: 1)
        let push = RoutineDay(order: 0, name: "Push", kind: .strength)
        let pull = RoutineDay(order: 1, name: "Pull", kind: .strength)
        let legs = RoutineDay(order: 2, name: "Legs", kind: .strength)
        let run = RoutineDay(order: 3, name: "Endurance", kind: .run, runType: .easy, runTargetMinutes: 45)
        return Program(name: "PPL + course", sessionsPerWeek: weeklyTarget,
                       weekLayout: [push.id, pull.id, legs.id, push.id, nil, run.id, nil], days: [push, pull, legs, run],
                       createdAt: created, updatedAt: created)
    }

    /// Les dépôts remplis : le programme actif, les séances, les scores et les records recalculés par `RecordBook`.
    static func twentyWeeks() async throws -> StatsRepositories {
        let repositories = StatsRepositories()
        let program = program()
        try await repositories.programs.save(program)
        // L'onboarding vient après la première séance importée : l'historique démarre à la première séance, la semaine 1.
        let onboarded = monday(ofWeek: 3)
        try await repositories.profiles.save(UserProfile(restWeekdays: [.friday, .sunday], onboardingCompletedAt: onboarded,
                                                         activeProgramID: program.id))
        let sessions = sessions(programID: program.id)
        for session in sessions { try await repositories.workouts.save(session) }
        for recovery in recoveries() { try await repositories.recoveries.save(recovery) }
        let directory = ExerciseDirectory(library: .bundled, userExercises: [])
        let book = RecordBook.compute(sessions: sessions, loadKind: directory.loadKind(of:), now: now)
        try await repositories.records.replaceAll(with: book.records)
        return repositories
    }
}
