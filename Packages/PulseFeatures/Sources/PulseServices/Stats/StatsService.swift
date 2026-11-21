import Foundation
import PulseContent
import PulseDomain

/// Les cinq vues Stats d'une période, construites depuis une seule lecture des dépôts.
public struct StatsSnapshot: Sendable, Equatable {
    public var period: StatsPeriod
    public var load: LoadStats
    public var biometry: BiometryStats
    public var muscles: MuscleStats
    public var attendance: AttendanceStats
    public var records: RecordStats

    public init(period: StatsPeriod, load: LoadStats, biometry: BiometryStats, muscles: MuscleStats, attendance: AttendanceStats,
                records: RecordStats) {
        self.period = period
        self.load = load
        self.biometry = biometry
        self.muscles = muscles
        self.attendance = attendance
        self.records = records
    }
}

/// Lit les dépôts une fois (séances de tout l'historique, scores depuis la période précédente, records, exercices perso), puis
/// confie le calcul aux fonctions pures de `Stats` (spec M7 §4 et §11). Rien n'est stocké : une séance corrigée ou importée se
/// retrouve au prochain `snapshot`.
public struct StatsService: Sendable {
    let profiles: any ProfileRepository
    let programs: any ProgramRepository
    let workouts: any WorkoutRepository
    let recoveries: any RecoveryRepository
    let records: any PersonalRecordRepository
    let userExercises: any UserExerciseRepository
    let library: ContentLibrary
    let calendar: Calendar
    let now: @Sendable () -> Date

    public init(profiles: any ProfileRepository, programs: any ProgramRepository, workouts: any WorkoutRepository,
                recoveries: any RecoveryRepository, records: any PersonalRecordRepository, userExercises: any UserExerciseRepository,
                library: ContentLibrary, calendar: Calendar, now: @escaping @Sendable () -> Date) {
        self.profiles = profiles
        self.programs = programs
        self.workouts = workouts
        self.recoveries = recoveries
        self.records = records
        self.userExercises = userExercises
        self.library = library
        self.calendar = calendar
        self.now = now
    }

    public func snapshot(for period: StatsPeriod) async throws -> StatsSnapshot {
        let now = now()
        let end = period.interval(now: now, calendar: calendar).end
        let profile = try await profiles.load()
        let program = try await activeProgram(of: profile)
        // Toutes les séances : la meilleure série remonte à tout l'historique.
        let sessions = try await workouts.sessions(from: .distantPast, to: end)
        // Les scores de la période et de celle d'avant, pour les comparaisons des tuiles.
        let previousStart = period.previousInterval(now: now, calendar: calendar).start
        let scores = try await recoveries.dailyRecoveries(from: previousStart, to: end)
        let personalRecords = try await records.records(for: nil)
        // Les exercices archivés restent connus : une ancienne séance peut encore les nommer.
        let directory = ExerciseDirectory(library: library, userExercises: try await userExercises.all(includeArchived: true))

        let onboardingCompletedAt = profile?.onboardingCompletedAt
        let historyStart = ([onboardingCompletedAt] + [sessions.map(\.startedAt).min()]).compactMap { $0 }.min()
        let target = WeekStreak.target(program: program, profile: profile)
        var deloadUntil: Date?
        if case .active(_, let until) = Deload.status(profile: profile, now: now, calendar: calendar) { deloadUntil = until }

        return StatsSnapshot(
            period: period,
            load: LoadStats.make(sessions: sessions, onboardingCompletedAt: onboardingCompletedAt, deloadUntil: deloadUntil,
                                 period: period, now: now, calendar: calendar),
            biometry: BiometryStats.make(recoveries: scores, period: period, now: now, calendar: calendar),
            muscles: MuscleStats.make(sessions: sessions, directory: directory, period: period, now: now, calendar: calendar),
            attendance: AttendanceStats.make(sessions: sessions, target: target, historyStart: historyStart, period: period,
                                             now: now, calendar: calendar),
            records: RecordStats.make(records: personalRecords, sessions: sessions, directory: directory, period: period,
                                      now: now, calendar: calendar))
    }

    /// Le programme actif du profil, comme `PlanningService`.
    private func activeProgram(of profile: UserProfile?) async throws -> Program? {
        guard let id = profile?.activeProgramID else { return nil }
        return try await programs.program(id: id)
    }
}
