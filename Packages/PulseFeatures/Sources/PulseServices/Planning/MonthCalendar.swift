import Foundation
import PulseDomain

/// Un jour de la grille du mois (spec M6 §6).
public struct MonthDay: Sendable, Equatable, Identifiable {
    public var date: Date
    /// Faux pour les jours des mois voisins qui complètent la première et la dernière semaine.
    public var isInMonth: Bool
    public var isToday: Bool
    /// Les disciplines faites ce jour-là, musculation puis course puis vélo.
    public var done: [SessionKind]
    /// Deux séances ou plus, ou un record battu.
    public var hasMark: Bool
    /// La discipline prévue, aujourd'hui ou plus tard, quand rien n'est encore fait.
    public var planned: RoutineDayKind?
    /// Les séances faites ce jour-là, de la plus ancienne à la plus récente : de quoi ouvrir leur détail.
    public var sessions: [MonthDaySession]
    /// Un autre entraînement d'Apple Santé ce jour-là (natation, HIIT, sport…), montré d'une icône neutre (`HealthActivities`).
    public var hasActivity: Bool

    public init(date: Date, isInMonth: Bool, isToday: Bool, done: [SessionKind], hasMark: Bool, planned: RoutineDayKind?,
                sessions: [MonthDaySession] = [], hasActivity: Bool = false) {
        self.date = date
        self.isInMonth = isInMonth
        self.isToday = isToday
        self.done = done
        self.hasMark = hasMark
        self.planned = planned
        self.sessions = sessions
        self.hasActivity = hasActivity
    }

    public var id: Date { date }
}

/// Une séance faite un jour du calendrier : son identifiant et sa discipline.
public struct MonthDaySession: Sendable, Equatable {
    public var id: UUID
    public var kind: SessionKind

    public init(id: UUID, kind: SessionKind) {
        self.id = id
        self.kind = kind
    }
}

/// Un mois en semaines entières, du lundi au dimanche.
public struct MonthGrid: Sendable, Equatable {
    /// Le premier jour du mois, à minuit.
    public var month: Date
    public var weeks: [[MonthDay]]

    public init(month: Date, weeks: [[MonthDay]]) {
        self.month = month
        self.weeks = weeks
    }
}

public enum MonthCalendar {
    /// Le premier jour du mois de `date`, à minuit.
    public static func monthStart(of date: Date, calendar: Calendar) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? calendar.startOfDay(for: date)
    }

    /// Le premier lundi affiché et le lendemain du dernier dimanche affiché pour le mois de `month`.
    public static func visibleRange(of month: Date, calendar: Calendar) -> DateInterval {
        let first = monthStart(of: month, calendar: calendar)
        let next = calendar.date(byAdding: .month, value: 1, to: first) ?? first
        let lastDay = calendar.date(byAdding: .day, value: -1, to: next) ?? first
        let start = WeekSchedule.weekStart(of: first, calendar: calendar)
        let lastWeek = WeekSchedule.weekStart(of: lastDay, calendar: calendar)
        let end = calendar.date(byAdding: .day, value: 7, to: lastWeek) ?? next
        return DateInterval(start: start, end: end)
    }

    public static func grid(month: Date, context: ScheduleContext, now: Date) -> MonthGrid {
        let calendar = context.calendar
        let first = monthStart(of: month, calendar: calendar)
        let range = visibleRange(of: first, calendar: calendar)
        let today = calendar.startOfDay(for: now)
        var days = [MonthDay]()
        var date = range.start
        while date < range.end {
            days.append(day(on: date, month: first, context: context, today: today))
            guard let next = calendar.date(byAdding: .day, value: 1, to: date) else { break }
            date = next
        }
        let weeks = stride(from: 0, to: days.count, by: 7).map { Array(days[$0..<min($0 + 7, days.count)]) }
        return MonthGrid(month: first, weeks: weeks)
    }

    private static func day(on date: Date, month: Date, context: ScheduleContext, today: Date) -> MonthDay {
        let calendar = context.calendar
        let done = context.sessions.filter { calendar.isDate($0.startedAt, inSameDayAs: date) && WeekSchedule.shows($0) }
        let kinds = SessionKind.allCases.filter { kind in done.contains { $0.kind == kind } }
        let hasRecord = done.contains { session in session.sets.contains(where: \.isPersonalRecord) }
        var planned: RoutineDayKind?
        if kinds.isEmpty, date >= today, let program = context.program {
            planned = TodayPlanner.routineDay(of: program, on: date, calendar: calendar, overrides: context.overrides)?.kind
        }
        return MonthDay(date: date, isInMonth: calendar.isDate(date, equalTo: month, toGranularity: .month),
                        isToday: calendar.isDate(date, inSameDayAs: today), done: kinds, hasMark: done.count >= 2 || hasRecord,
                        planned: planned,
                        sessions: done.sorted { $0.startedAt < $1.startedAt }.map { MonthDaySession(id: $0.id, kind: $0.kind) },
                        hasActivity: context.activities.contains { calendar.isDate($0, inSameDayAs: date) })
    }
}
