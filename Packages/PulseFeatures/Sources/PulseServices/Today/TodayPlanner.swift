import Foundation
import PulseDomain

/// Une séance à venir : le jour de routine et le jour de la semaine où il tombe.
public struct NextSession: Sendable, Equatable {
    public var day: RoutineDay
    public var weekday: Weekday

    public init(day: RoutineDay, weekday: Weekday) {
        self.day = day
        self.weekday = weekday
    }
}

/// Ce que le programme actif prévoit pour une date donnée.
public enum PlannedDay: Sendable, Equatable {
    case noProgram
    case rest(next: NextSession?)
    case strength(RoutineDay)
    case run(RoutineDay)
}

/// Lit la semaine datée du programme actif pour dire ce qui est prévu un jour donné : une ligne `ScheduledDay` de ce jour
/// remplace la semaine type (spec M6 §4).
public enum TodayPlanner {
    public static func plan(program: Program?, on date: Date, calendar: Calendar, overrides: [ScheduledDay] = []) -> PlannedDay {
        guard let program else { return .noProgram }
        if let day = routineDay(of: program, on: date, calendar: calendar, overrides: overrides) {
            return day.kind == .run ? .run(day) : .strength(day)
        }
        return .rest(next: nextSession(in: program, after: date, calendar: calendar, overrides: overrides))
    }

    /// Le jour de routine prévu à `date` : celui de la ligne du jour si elle existe (aucun pour un repos), sinon celui de la
    /// semaine type. Une ligne d'un autre programme est ignorée. Une course que la règle des jambes lourdes a rendue facile
    /// revient en sortie facile (spec M6 §9).
    public static func routineDay(of program: Program, on date: Date, calendar: Calendar, overrides: [ScheduledDay]) -> RoutineDay? {
        if let override = override(on: date, for: program, calendar: calendar, in: overrides) {
            guard override.kind != .rest, let id = override.routineDayID,
                  var day = program.days.first(where: { $0.id == id }) else { return nil }
            if AntiInterference.isEasedRun(override), day.kind == .run {
                day.runType = .easy
            }
            return day
        }
        return routineDay(of: program, on: Weekday(date: date, calendar: calendar))
    }

    /// La ligne de la semaine datée qui vaut pour `date` et `program`.
    public static func override(on date: Date, for program: Program, calendar: Calendar, in overrides: [ScheduledDay]) -> ScheduledDay? {
        overrides.last { calendar.isDate($0.date, inSameDayAs: date) && ($0.programID == nil || $0.programID == program.id) }
    }

    /// Le jour de routine de la semaine type pour `weekday`.
    public static func routineDay(of program: Program, on weekday: Weekday) -> RoutineDay? {
        guard program.weekLayout.indices.contains(weekday.index), let id = program.weekLayout[weekday.index] else { return nil }
        return program.days.first { $0.id == id }
    }

    /// La première séance prévue dans les 7 jours qui suivent `date`.
    private static func nextSession(in program: Program, after date: Date, calendar: Calendar, overrides: [ScheduledDay]) -> NextSession? {
        for offset in 1...7 {
            guard let next = calendar.date(byAdding: .day, value: offset, to: date) else { continue }
            if let day = routineDay(of: program, on: next, calendar: calendar, overrides: overrides) {
                return NextSession(day: day, weekday: Weekday(date: next, calendar: calendar))
            }
        }
        return nil
    }
}

extension PlannedDay {
    /// La séance prévue, de musculation ou de course ; `nil` un jour de repos ou sans programme.
    public var routineDay: RoutineDay? {
        switch self {
        case .strength(let day), .run(let day): day
        case .noProgram, .rest: nil
        }
    }
}
