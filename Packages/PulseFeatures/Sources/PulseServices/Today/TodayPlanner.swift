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

/// Lit la semaine type du programme actif pour dire ce qui est prévu aujourd'hui.
public enum TodayPlanner {
    public static func plan(program: Program?, on date: Date, calendar: Calendar) -> PlannedDay {
        guard let program else { return .noProgram }
        let today = Weekday(date: date, calendar: calendar)
        if let day = routineDay(of: program, on: today) {
            return day.kind == .run ? .run(day) : .strength(day)
        }
        return .rest(next: nextSession(in: program, after: today))
    }

    /// Le premier jour planifié après `today`, en bouclant sur la semaine (aujourd'hui compris, la semaine suivante).
    private static func nextSession(in program: Program, after today: Weekday) -> NextSession? {
        for offset in 1...7 {
            let weekday = Weekday.allCases[(today.index + offset) % Weekday.allCases.count]
            if let day = routineDay(of: program, on: weekday) {
                return NextSession(day: day, weekday: weekday)
            }
        }
        return nil
    }

    private static func routineDay(of program: Program, on weekday: Weekday) -> RoutineDay? {
        guard program.weekLayout.indices.contains(weekday.index), let id = program.weekLayout[weekday.index] else { return nil }
        return program.days.first { $0.id == id }
    }
}
