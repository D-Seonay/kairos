import Foundation
import PulseDomain

/// Ce qui empêche un déplacement.
public enum PlanningError: Error, Equatable, Sendable {
    /// Pas de programme actif : il n'y a rien à déplacer.
    case noProgram
    /// Un des deux jours est passé, validé, hors de la semaine de l'autre, ou les deux jours sont vides.
    case notMovable
}

/// La semaine en cours, la série et le programme lus ensemble pour l'onglet Planning.
public struct PlanningOverview: Sendable, Equatable {
    public var profile: UserProfile?
    public var program: Program?
    public var days: [PlanningDay]
    public var streak: StreakSummary
    /// Vrai quand un déplacement de l'utilisateur existe dans la semaine : « Rétablir la semaine type » s'affiche.
    public var hasUserMoves: Bool
    /// Le premier jour d'activité connu (fin de l'onboarding ou première séance) : le mois le plus ancien qu'on peut ouvrir.
    public var historyStart: Date?

    public init(profile: UserProfile?, program: Program?, days: [PlanningDay], streak: StreakSummary, hasUserMoves: Bool,
                historyStart: Date?) {
        self.profile = profile
        self.program = program
        self.days = days
        self.streak = streak
        self.hasUserMoves = hasUserMoves
        self.historyStart = historyStart
    }
}

/// Le seul chemin vers la semaine datée (spec M6 §4 à §6) : la lire, y échanger deux jours, la rétablir, et en tirer la série
/// et le mois.
public struct PlanningService: Sendable {
    private let profiles: any ProfileRepository
    private let programs: any ProgramRepository
    private let workouts: any WorkoutRepository
    private let scheduledDays: any ScheduledDayRepository
    private let calendar: Calendar
    private let now: @Sendable () -> Date

    public init(profiles: any ProfileRepository, programs: any ProgramRepository, workouts: any WorkoutRepository,
                scheduledDays: any ScheduledDayRepository, calendar: Calendar, now: @escaping @Sendable () -> Date) {
        self.profiles = profiles
        self.programs = programs
        self.workouts = workouts
        self.scheduledDays = scheduledDays
        self.calendar = calendar
        self.now = now
    }

    /// La semaine en cours et la série. Toutes les séances sont lues, pour que la série remonte aussi loin que l'historique.
    public func overview() async throws -> PlanningOverview {
        let now = now()
        let (profile, program) = try await profileAndProgram()
        let weekStart = WeekSchedule.weekStart(of: now, calendar: calendar)
        let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? now
        let overrides = try await scheduledDays.days(from: weekStart, to: weekEnd)
        let sessions = try await workouts.sessions(from: .distantPast, to: weekEnd)
        let historyStart = ([profile?.onboardingCompletedAt] + [sessions.first?.startedAt]).compactMap { $0 }.min()
        let context = ScheduleContext(program: program, overrides: overrides, sessions: sessions.filter { $0.startedAt >= weekStart },
                                      restWeekdays: profile?.restWeekdays ?? [], calendar: calendar)
        let days = WeekSchedule.days(weekStart: weekStart, context: context, now: now)
        let streak = WeekStreak.summary(sessions: sessions, target: WeekStreak.target(program: program, profile: profile),
                                        historyStart: historyStart, now: now, calendar: calendar)
        let moved = program.map { program in overrides.contains { $0.moveReason == .user && ($0.programID ?? program.id) == program.id } }
        return PlanningOverview(profile: profile, program: program, days: days, streak: streak, hasUserMoves: moved ?? false,
                                historyStart: historyStart)
    }

    /// La grille du mois de `month`.
    public func month(_ month: Date) async throws -> MonthGrid {
        let range = MonthCalendar.visibleRange(of: month, calendar: calendar)
        let (_, program) = try await profileAndProgram()
        let overrides = try await scheduledDays.days(from: range.start, to: range.end)
        let sessions = try await workouts.sessions(from: range.start, to: range.end)
        return MonthCalendar.grid(month: month, context: ScheduleContext(program: program, overrides: overrides, sessions: sessions,
                                                                         calendar: calendar), now: now())
    }

    /// Les lignes de la semaine datée entre `from` et `to`, pour `TodayPlanner`.
    public func overrides(from: Date, to: Date) async throws -> [ScheduledDay] {
        try await scheduledDays.days(from: from, to: to)
    }

    /// Échange les séances prévues de deux jours de la semaine en cours, aujourd'hui ou plus tard et non validés (spec M6 §4).
    /// Un jour qui retrouve sa séance de la semaine type perd sa ligne.
    public func swap(_ first: Date, _ second: Date) async throws {
        let now = now()
        let (profile, program) = try await profileAndProgram()
        guard let program else { throw PlanningError.noProgram }
        let weekStart = WeekSchedule.weekStart(of: now, calendar: calendar)
        let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? now
        let overrides = try await scheduledDays.days(from: weekStart, to: weekEnd)
        let sessions = try await workouts.sessions(from: weekStart, to: weekEnd)
        let today = calendar.startOfDay(for: now)
        let context = ScheduleContext(program: program, overrides: overrides, sessions: sessions,
                                      restWeekdays: profile?.restWeekdays ?? [], calendar: calendar)
        let days = [first, second].map { WeekSchedule.day(on: calendar.startOfDay(for: $0), context: context, today: today) }
        guard days[0].date != days[1].date, days.allSatisfy({ $0.isMovable && $0.date >= weekStart && $0.date < weekEnd }),
              days.contains(where: { $0.routine != nil }) else { throw PlanningError.notMovable }
        try await place(days[1].routine, from: days[1], on: days[0], program: program, now: now)
        try await place(days[0].routine, from: days[0], on: days[1], program: program, now: now)
    }

    /// Supprime les déplacements de l'utilisateur dans la semaine en cours.
    public func restoreWeek() async throws {
        let now = now()
        let weekStart = WeekSchedule.weekStart(of: now, calendar: calendar)
        let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? now
        for day in try await scheduledDays.days(from: weekStart, to: weekEnd) where day.moveReason == .user {
            try await scheduledDays.delete(id: day.id)
        }
    }

    // MARK: - Interne

    private func profileAndProgram() async throws -> (UserProfile?, Program?) {
        let profile = try await profiles.load()
        guard let id = profile?.activeProgramID else { return (profile, nil) }
        return (profile, try await programs.program(id: id))
    }

    /// Met `routine`, venue du jour `origin`, sur le jour `target` : met à jour sa ligne, en crée une, ou la supprime quand la
    /// semaine type prévoit déjà `routine` ce jour-là.
    private func place(_ routine: RoutineDay?, from origin: PlanningDay, on target: PlanningDay, program: Program, now: Date) async throws {
        let template = TodayPlanner.routineDay(of: program, on: target.weekday)
        if routine?.id == template?.id {
            if let existing = target.scheduled { try await scheduledDays.delete(id: existing.id) }
            return
        }
        let kind: ScheduledDayKind = switch routine?.kind {
        case .strength: .strength
        case .run: .run
        case nil: .rest
        }
        var line = target.scheduled ?? ScheduledDay(date: target.date, programID: program.id, title: "", kind: kind, status: .planned,
                                                    createdAt: now, updatedAt: now)
        line.programID = program.id
        line.routineDayID = routine?.id
        line.title = routine?.name ?? String(localized: "Repos", bundle: .module)
        line.kind = kind
        line.status = .planned
        line.movedFromDate = routine == nil ? nil : (origin.movedFrom ?? origin.date)
        line.moveReason = .user
        line.moveReasonText = nil
        line.updatedAt = now
        try await scheduledDays.save(line)
    }
}
