import Foundation
import PulseDomain

extension PlanningService {
    /// Refuse ce qu'une règle a placé sur `date` (spec M6 §9) : le jour, et l'autre jour d'un déplacement, retrouvent la semaine
    /// type par une ligne `.user`, que les règles ne touchent plus.
    public func keepPlanned(_ date: Date) async throws {
        let now = now()
        let (profile, program) = try await profileAndProgram()
        guard let program else { throw PlanningError.noProgram }
        let weekStart = WeekSchedule.weekStart(of: now, calendar: calendar)
        let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? now
        let today = calendar.startOfDay(for: now)
        let overrides = try await scheduledDays.days(from: weekStart, to: weekEnd)
        let context = ScheduleContext(program: program, overrides: overrides,
                                      sessions: try await workouts.sessions(from: weekStart, to: weekEnd),
                                      restWeekdays: profile?.restWeekdays ?? [], calendar: calendar)
        let day = WeekSchedule.day(on: calendar.startOfDay(for: date), context: context, today: today)
        guard let line = day.scheduled, AntiInterference.isRule(line) else { throw PlanningError.notMovable }
        let partners = ruleMovePartners(of: line, in: overrides)
        guard day.isMovable else { throw PlanningError.notMovable }
        // L'autre jour d'un déplacement, s'il est passé ou fait, reste tel quel : on ne garde que les jours qui peuvent encore changer.
        let days = [day] + partners.map { WeekSchedule.day(on: calendar.startOfDay(for: $0.date), context: context, today: today) }
            .filter(\.isMovable)
        for target in days {
            guard var kept = target.scheduled else { continue }
            let routine = TodayPlanner.routineDay(of: program, on: target.weekday)
            kept.routineDayID = routine?.id
            kept.title = routine?.name ?? String(localized: "Repos", bundle: .module)
            kept.kind = Self.kind(of: routine)
            kept.movedFromDate = nil
            kept.moveReason = .user
            kept.moveReasonText = nil
            kept.updatedAt = now
            try await scheduledDays.save(kept)
        }
    }

    /// Avant un échange, les déplacements de règle qui touchent les jours échangés passent à l'utilisateur, tels quels : sinon
    /// la règle recalculerait l'autre jour d'un déplacement, et la course apparaîtrait deux fois. Rend vrai si un des jours
    /// échangés portait une ligne de règle.
    @discardableResult
    func adoptRuleMoves(touching days: [PlanningDay], in overrides: [ScheduledDay], today: Date, now: Date) async throws -> Bool {
        let lines = days.compactMap(\.scheduled).filter(AntiInterference.isRule)
        let partners = lines.flatMap { ruleMovePartners(of: $0, in: overrides) }
        for var partner in partners where partner.date >= today && !lines.contains(where: { $0.id == partner.id }) {
            partner.moveReason = .user
            partner.moveReasonText = nil
            partner.updatedAt = now
            try await scheduledDays.save(partner)
        }
        return !lines.isEmpty
    }

    /// L'autre jour d'un déplacement de règle : le jour d'origine d'une course déplacée, ou le jour où est allée la course partie
    /// de ce jour.
    private func ruleMovePartners(of line: ScheduledDay, in overrides: [ScheduledDay]) -> [ScheduledDay] {
        overrides.filter { other in
            guard other.id != line.id, AntiInterference.isRule(other), other.moveReason == line.moveReason else { return false }
            if let origin = line.movedFromDate, calendar.isDate(other.date, inSameDayAs: origin) { return true }
            return other.movedFromDate.map { calendar.isDate($0, inSameDayAs: line.date) } ?? false
        }
    }

    static func kind(of routine: RoutineDay?) -> ScheduledDayKind {
        switch routine?.kind {
        case .strength: .strength
        case .run: .run
        case nil: .rest
        }
    }
}
