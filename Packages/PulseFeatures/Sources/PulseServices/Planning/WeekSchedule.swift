import Foundation
import PulseDomain

/// Ce qu'un jour de la semaine datée est devenu (spec M6 §4).
public enum PlanningDayState: Sendable, Equatable {
    /// Une séance prévue a été faite, ou une séance a eu lieu un jour de repos.
    case done
    /// Un jour passé, prévu, sans séance qui le valide.
    case missed
    /// Une séance prévue aujourd'hui ou plus tard.
    case planned
    case rest
    /// Un jour de repos imposé par le profil.
    case mandatoryRest
}

/// Un jour de la semaine datée : ce qui était prévu, ce qui a été fait, et s'il a été déplacé.
public struct PlanningDay: Sendable, Equatable, Identifiable {
    public var date: Date
    public var weekday: Weekday
    /// La séance prévue ce jour-là, après les déplacements.
    public var routine: RoutineDay?
    /// La ligne de la semaine datée de ce jour, s'il y en a une.
    public var scheduled: ScheduledDay?
    /// Les séances faites ce jour-là, de la plus ancienne à la plus récente : musculation terminée, courses et vélos.
    public var sessions: [WorkoutSession]
    public var isToday: Bool
    public var isPast: Bool
    public var state: PlanningDayState

    public init(date: Date, weekday: Weekday, routine: RoutineDay?, scheduled: ScheduledDay?, sessions: [WorkoutSession],
                isToday: Bool, isPast: Bool, state: PlanningDayState) {
        self.date = date
        self.weekday = weekday
        self.routine = routine
        self.scheduled = scheduled
        self.sessions = sessions
        self.isToday = isToday
        self.isPast = isPast
        self.state = state
    }

    public var id: Date { date }

    /// La date d'origine d'une séance déplacée.
    public var movedFrom: Date? {
        scheduled?.movedFromDate
    }

    /// Un jour d'aujourd'hui ou plus tard, pas encore validé, peut échanger sa séance avec un autre (spec M6 §4).
    public var isMovable: Bool {
        !isPast && state != .done
    }
}

/// Ce qu'il faut pour dire ce qu'un jour est devenu : le programme actif, les lignes de la semaine datée, les séances et les
/// jours de repos imposés.
public struct ScheduleContext: Sendable {
    public var program: Program?
    public var overrides: [ScheduledDay]
    public var sessions: [WorkoutSession]
    public var restWeekdays: [Weekday]
    public var calendar: Calendar

    public init(program: Program?, overrides: [ScheduledDay] = [], sessions: [WorkoutSession] = [], restWeekdays: [Weekday] = [],
                calendar: Calendar) {
        self.program = program
        self.overrides = overrides
        self.sessions = sessions
        self.restWeekdays = restWeekdays
        self.calendar = calendar
    }
}

/// Construit la semaine datée : la semaine type du programme, les lignes `ScheduledDay` qui la remplacent, et les séances
/// qui valident chaque jour.
public enum WeekSchedule {
    /// Le lundi de la semaine de `date`, à minuit.
    public static func weekStart(of date: Date, calendar: Calendar) -> Date {
        let day = calendar.startOfDay(for: date)
        return calendar.date(byAdding: .day, value: -Weekday(date: day, calendar: calendar).index, to: day) ?? day
    }

    /// Les 7 jours de la semaine qui commence le lundi `weekStart`.
    public static func days(weekStart: Date, context: ScheduleContext, now: Date) -> [PlanningDay] {
        let calendar = context.calendar
        let today = calendar.startOfDay(for: now)
        return (0..<Weekday.allCases.count).compactMap { offset -> PlanningDay? in
            guard let date = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: weekStart)) else { return nil }
            return day(on: date, context: context, today: today)
        }
    }

    /// Le jour `date` (à minuit) de la semaine datée.
    public static func day(on date: Date, context: ScheduleContext, today: Date) -> PlanningDay {
        let calendar = context.calendar
        let program = context.program
        let overrides = context.overrides
        let weekday = Weekday(date: date, calendar: calendar)
        let routine = program.flatMap { TodayPlanner.routineDay(of: $0, on: date, calendar: calendar, overrides: overrides) }
        let scheduled = program.flatMap { TodayPlanner.override(on: date, for: $0, calendar: calendar, in: overrides) }
        let done = context.sessions.filter { calendar.isDate($0.startedAt, inSameDayAs: date) && shows($0) }
        let isPast = date < today
        let state: PlanningDayState
        if let routine {
            if done.contains(where: { validates($0, routine) }) {
                state = .done
            } else {
                state = isPast ? .missed : .planned
            }
        } else if !done.isEmpty {
            state = .done
        } else {
            state = context.restWeekdays.contains(weekday) ? .mandatoryRest : .rest
        }
        return PlanningDay(date: date, weekday: weekday, routine: routine, scheduled: scheduled, sessions: done,
                           isToday: calendar.isDate(date, inSameDayAs: today), isPast: isPast, state: state)
    }

    /// Une séance de musculation terminée, une course ou un vélo : jamais une séance en cours ou abandonnée.
    static func shows(_ session: WorkoutSession) -> Bool {
        session.status == .completed
    }

    /// Une séance de musculation terminée valide un jour de musculation, quelle que soit sa routine ; une course valide un
    /// jour de course (spec M6 §4).
    static func validates(_ session: WorkoutSession, _ routine: RoutineDay) -> Bool {
        switch routine.kind {
        case .strength: session.kind == .strength
        case .run: session.kind == .run
        }
    }
}
