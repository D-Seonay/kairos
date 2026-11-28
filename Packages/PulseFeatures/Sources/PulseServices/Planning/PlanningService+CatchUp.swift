import Foundation
import PulseDomain

extension PlanningService {
    /// Rattrape la séance manquée de `source`, un jour passé de la semaine en cours, sur `target`, un jour à venir de la même
    /// semaine (`CatchUp`). Une semaine passée ne se rattrape pas.
    public func catchUp(_ source: Date, on target: Date) async throws {
        try await writes.run { try await self.catchUpInQueue(source, on: target) }
    }

    private func catchUpInQueue(_ source: Date, on target: Date) async throws {
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
        let days = [source, target].map { WeekSchedule.day(on: calendar.startOfDay(for: $0), context: context, today: today) }
        guard days.allSatisfy({ $0.date >= weekStart && $0.date < weekEnd }),
              CatchUp.targets(for: days[0], in: [days[1]]).count == 1 else { throw PlanningError.notMovable }
        try await adoptRuleMoves(touching: [days[1]], in: overrides, today: today, now: now)
        let lines = CatchUp.lines(source: days[0], target: days[1], programID: program.id, now: now)
        try await scheduledDays.save(lines.target)
        try await scheduledDays.save(lines.source)
    }
}
