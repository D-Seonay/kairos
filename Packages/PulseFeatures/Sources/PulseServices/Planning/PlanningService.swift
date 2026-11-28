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
    /// Le début de l'historique pour le ratio de charge (`TrainingLoad.historyStart`), lu sur les mêmes séances.
    public var loadHistoryStart: Date?

    public init(profile: UserProfile?, program: Program?, days: [PlanningDay], streak: StreakSummary, hasUserMoves: Bool,
                historyStart: Date?, loadHistoryStart: Date? = nil) {
        self.profile = profile
        self.program = program
        self.days = days
        self.streak = streak
        self.hasUserMoves = hasUserMoves
        self.historyStart = historyStart
        self.loadHistoryStart = loadHistoryStart
    }
}

/// Le seul chemin vers la semaine datée (spec M6 §4 à §6) : la lire, y échanger deux jours, la rétablir, et en tirer la série
/// et le mois.
public struct PlanningService: Sendable {
    let profiles: any ProfileRepository
    let programs: any ProgramRepository
    let workouts: any WorkoutRepository
    let scheduledDays: any ScheduledDayRepository
    let calendar: Calendar
    let now: @Sendable () -> Date
    /// La file des écritures de la semaine datée (échange, refus d'une règle, rétablissement). Le passage du jour qui reçoit ce
    /// service passe par la même file : un déplacement et les règles anti-interférence ne s'écrasent plus l'un l'autre.
    let writes = SerialTaskQueue()
    /// Les autres entraînements d'Apple Santé : l'icône neutre du mois et la charge des widgets ; sans eux, seules les séances.
    let activities: HealthActivities?

    public init(profiles: any ProfileRepository, programs: any ProgramRepository, workouts: any WorkoutRepository,
                scheduledDays: any ScheduledDayRepository, calendar: Calendar, now: @escaping @Sendable () -> Date,
                activities: HealthActivities? = nil) {
        self.activities = activities
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
        let loadStart = TrainingLoad.historyStart(sessions: sessions, onboardingCompletedAt: profile?.onboardingCompletedAt)
        return PlanningOverview(profile: profile, program: program, days: days, streak: streak, hasUserMoves: moved ?? false,
                                historyStart: historyStart, loadHistoryStart: loadStart)
    }

    /// La grille du mois de `month`.
    public func month(_ month: Date) async throws -> MonthGrid {
        let range = MonthCalendar.visibleRange(of: month, calendar: calendar)
        let (_, program) = try await profileAndProgram()
        let overrides = try await scheduledDays.days(from: range.start, to: range.end)
        let sessions = try await workouts.sessions(from: range.start, to: range.end)
        let activities = await activities?.starts(from: range.start, to: range.end) ?? []
        let context = ScheduleContext(program: program, overrides: overrides, sessions: sessions, calendar: calendar,
                                      activities: activities)
        return MonthCalendar.grid(month: month, context: context, now: now())
    }

    /// Les lignes de la semaine datée entre `from` et `to`, pour `TodayPlanner`.
    public func overrides(from: Date, to: Date) async throws -> [ScheduledDay] {
        try await scheduledDays.days(from: from, to: to)
    }

    /// Échange les séances prévues de deux jours de la semaine en cours, aujourd'hui ou plus tard et non validés (spec M6 §4).
    /// Un jour qui retrouve sa séance de la semaine type perd sa ligne.
    public func swap(_ first: Date, _ second: Date) async throws {
        try await writes.run { try await self.swapInQueue(first, second) }
    }

    /// Supprime les déplacements de l'utilisateur dans la semaine en cours.
    public func restoreWeek() async throws {
        try await writes.run {
            let now = self.now()
            let weekStart = WeekSchedule.weekStart(of: now, calendar: self.calendar)
            let weekEnd = self.calendar.date(byAdding: .day, value: 7, to: weekStart) ?? now
            for day in try await self.scheduledDays.days(from: weekStart, to: weekEnd) where day.moveReason == .user {
                try await self.scheduledDays.delete(id: day.id)
            }
        }
    }

    // MARK: - Interne

    private func swapInQueue(_ first: Date, _ second: Date) async throws {
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
        let touchesRules = try await adoptRuleMoves(touching: days, in: overrides, today: today, now: now)
        try await place(days[1].routine, from: days[1], on: days[0], program: program, keepsLine: touchesRules, now: now)
        try await place(days[0].routine, from: days[0], on: days[1], program: program, keepsLine: touchesRules, now: now)
    }

    func profileAndProgram() async throws -> (UserProfile?, Program?) {
        let profile = try await profiles.load()
        guard let id = profile?.activeProgramID else { return (profile, nil) }
        return (profile, try await programs.program(id: id))
    }

    // swiftlint:disable function_parameter_count
    /// Met `routine`, venue du jour `origin`, sur le jour `target` : met à jour sa ligne, en crée une, ou la supprime quand la
    /// semaine type prévoit déjà `routine` ce jour-là. `keepsLine` garde une ligne `.user` même dans ce cas : après un échange
    /// qui défait un déplacement de règle, la règle ne doit pas le refaire au passage suivant.
    private func place(_ routine: RoutineDay?, from origin: PlanningDay, on target: PlanningDay, program: Program, keepsLine: Bool,
                       now: Date) async throws {
        let template = TodayPlanner.routineDay(of: program, on: target.weekday)
        if routine?.id == template?.id, !keepsLine {
            if let existing = target.scheduled { try await scheduledDays.delete(id: existing.id) }
            return
        }
        let kind = Self.kind(of: routine)
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
    // swiftlint:enable function_parameter_count
}
