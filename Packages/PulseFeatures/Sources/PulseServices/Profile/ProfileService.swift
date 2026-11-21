import Foundation
import PulseContent
import PulseDomain

/// Ce que la page Profil affiche en haut : l'identité, la série, le score du matin, les records et la vitrine.
public struct ProfileSummary: Sendable, Equatable {
    public var firstName: String?
    /// Les séances comptées (`WeekStreak.counts`).
    public var sessionsTotal: Int
    public var firstSession: Date?
    public var streakWeeks: Int
    /// Le score du jour ; `nil` sans score aujourd'hui.
    public var morningScore: Double?
    /// Le score du jour est estimé d'après le questionnaire du matin, faute de mesures ; faux sans score.
    public var morningScoreIsEstimated: Bool
    /// Les levés de base qui ont un record, dans l'ordre de `RecordStats.mainLifts`.
    public var mainLifts: [StrengthRecordLine]
    /// Toujours trois lignes, une par distance.
    public var runs: [RunBest]
    public var badges: BadgeShelf

    public init(firstName: String?, sessionsTotal: Int, firstSession: Date?, streakWeeks: Int, morningScore: Double?,
                morningScoreIsEstimated: Bool = false, mainLifts: [StrengthRecordLine], runs: [RunBest], badges: BadgeShelf) {
        self.firstName = firstName
        self.sessionsTotal = sessionsTotal
        self.firstSession = firstSession
        self.streakWeeks = streakWeeks
        self.morningScore = morningScore
        self.morningScoreIsEstimated = morningScoreIsEstimated
        self.mainLifts = mainLifts
        self.runs = runs
        self.badges = badges
    }
}

/// Assemble le résumé du profil depuis les dépôts, comme `StatsService` : rien n'est stocké (spec M7 §13).
public struct ProfileService: Sendable {
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

    public func summary() async throws -> ProfileSummary {
        let now = now()
        let today = calendar.startOfDay(for: now)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? now
        let profile = try await profiles.load()
        let program = try await activeProgram(of: profile)
        let sessions = try await workouts.sessions(from: .distantPast, to: tomorrow)
        let recovery = try await recoveries.dailyRecoveries(from: today, to: tomorrow).first
        let personalRecords = try await records.records(for: nil)
        // Les exercices archivés restent connus : une ancienne séance peut encore les nommer.
        let directory = ExerciseDirectory(library: library, userExercises: try await userExercises.all(includeArchived: true))

        let historyStart = ([profile?.onboardingCompletedAt] + [sessions.map(\.startedAt).min()]).compactMap { $0 }.min()
        let target = WeekStreak.target(program: program, profile: profile)
        let counted = sessions.filter(WeekStreak.counts)
        let recordStats = RecordStats.make(records: personalRecords, sessions: sessions, directory: directory, period: .year,
                                       now: now, calendar: calendar)
        return ProfileSummary(
            firstName: profile?.firstName,
            sessionsTotal: counted.count,
            firstSession: counted.map(\.startedAt).min(),
            streakWeeks: WeekStreak.summary(sessions: sessions, target: target, historyStart: historyStart, now: now,
                                            calendar: calendar).streak,
            morningScore: recovery?.score,
            morningScoreIsEstimated: recovery?.isEstimated ?? false,
            mainLifts: recordStats.strength.filter { line in
                RecordStats.mainLifts.contains { line.exercise == .content(id: $0) }
            },
            runs: recordStats.runs,
            badges: Badges.make(sessions: sessions, target: target, historyStart: historyStart, now: now, calendar: calendar))
    }

    /// Le programme actif du profil, comme `StatsService`.
    private func activeProgram(of profile: UserProfile?) async throws -> Program? {
        guard let id = profile?.activeProgramID else { return nil }
        return try await programs.program(id: id)
    }
}
