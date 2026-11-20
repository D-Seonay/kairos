import Foundation
import PulseContent
import PulseDomain

/// Applique les règles anti-interférence à la semaine datée en cours, à chaque passage du jour (spec M6 §9) : écrit les lignes
/// qu'elles veulent sur les jours qu'elles gèrent, et efface celles qui ne servent plus.
public struct AntiInterferenceService: Sendable {
    private let profiles: any ProfileRepository
    private let programs: any ProgramRepository
    private let workouts: any WorkoutRepository
    private let scheduledDays: any ScheduledDayRepository
    private let userExercises: any UserExerciseRepository
    private let library: ContentLibrary
    private let calendar: Calendar
    private let now: @Sendable () -> Date

    public init(profiles: any ProfileRepository, programs: any ProgramRepository, workouts: any WorkoutRepository,
                scheduledDays: any ScheduledDayRepository, userExercises: any UserExerciseRepository, library: ContentLibrary,
                calendar: Calendar, now: @escaping @Sendable () -> Date) {
        self.profiles = profiles
        self.programs = programs
        self.workouts = workouts
        self.scheduledDays = scheduledDays
        self.userExercises = userExercises
        self.library = library
        self.calendar = calendar
        self.now = now
    }

    /// `nights` : les nuits que le passage vient de lire, pour le repos complet. Sans profil terminé ni programme actif, rien
    /// ne change.
    public func apply(nights: [NightSample]) async throws {
        let now = now()
        guard let profile = try await profiles.load(), profile.onboardingCompletedAt != nil, let id = profile.activeProgramID,
              let program = try await programs.program(id: id) else { return }
        let today = calendar.startOfDay(for: now)
        let weekStart = WeekSchedule.weekStart(of: now, calendar: calendar)
        guard let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart),
              let since = calendar.date(byAdding: .day, value: -(AntiInterference.daysWithoutRest + 1), to: today) else { return }
        let lines = try await scheduledDays.days(from: weekStart, to: weekEnd)
            .filter { $0.programID == nil || $0.programID == program.id }
        let sessions = try await workouts.sessions(from: since, to: weekEnd)
        let custom = (try? await userExercises.all(includeArchived: true)) ?? []
        let plan = AntiInterference.plan(AntiInterferenceInput(
            program: program, profile: profile, lines: lines, sessions: sessions, nights: nights,
            directory: ExerciseDirectory(library: library, userExercises: custom), calendar: calendar, now: now))
        try await write(plan, over: lines, program: program, now: now)
    }

    /// Met les lignes de règle des jours gérés d'accord avec `plan`, sans réécrire une ligne qui n'a pas changé. Une ligne de règle
    /// d'un jour géré que le plan ne réutilise pas est effacée : elle ne sert plus, ou elle double une autre ligne du même jour.
    private func write(_ plan: AntiInterferencePlan, over lines: [ScheduledDay], program: Program, now: Date) async throws {
        let managed = lines.filter { line in
            AntiInterference.isRule(line) && plan.managedDates.contains { calendar.isDate($0, inSameDayAs: line.date) }
        }
        var reused: Set<UUID> = []
        for wanted in plan.lines {
            let current = managed.first { calendar.isDate($0.date, inSameDayAs: wanted.date) }
            if let current { reused.insert(current.id) }
            var line = current ?? ScheduledDay(date: wanted.date, programID: program.id, title: "", kind: .rest, status: .planned,
                                               createdAt: now, updatedAt: now)
            line.programID = program.id
            line.routineDayID = wanted.routine?.id
            line.title = wanted.routine?.name ?? String(localized: "Repos", bundle: .module)
            line.kind = PlanningService.kind(of: wanted.routine)
            line.status = .planned
            line.movedFromDate = wanted.movedFromDate
            line.moveReason = wanted.reason
            line.moveReasonText = wanted.text
            guard line != current else { continue }
            line.updatedAt = now
            try await scheduledDays.save(line)
        }
        for line in managed where !reused.contains(line.id) {
            try await scheduledDays.delete(id: line.id)
        }
    }
}
