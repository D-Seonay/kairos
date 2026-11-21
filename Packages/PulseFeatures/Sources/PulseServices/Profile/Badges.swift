import Foundation
import PulseDomain

public enum BadgeKind: Sendable, Equatable, Hashable {
    /// Des semaines réussies d'affilée.
    case streak(weeks: Int)
    /// Un nombre de séances comptées.
    case sessions(count: Int)
    /// Un mois civil avec `Badges.fullMonthWeeks` semaines réussies.
    case firstFullMonth
}

/// Un badge de régularité : obtenu (avec sa date) ou à obtenir (avec sa progression).
public struct Badge: Sendable, Equatable, Identifiable {
    public var kind: BadgeKind
    /// `nil` tant que le badge n'est pas obtenu.
    public var earnedAt: Date?
    /// La progression : semaines d'affilée, séances, ou semaines réussies du meilleur mois.
    public var current: Int
    public var goal: Int

    public init(kind: BadgeKind, earnedAt: Date?, current: Int, goal: Int) {
        self.kind = kind
        self.earnedAt = earnedAt
        self.current = current
        self.goal = goal
    }

    public var progress: Double { goal > 0 ? min(1, Double(current) / Double(goal)) : 1 }

    public var id: BadgeKind { kind }
}

/// La vitrine : les badges obtenus, du plus ancien au plus récent, et au plus un badge suivant par famille.
public struct BadgeShelf: Sendable, Equatable {
    public var earned: [Badge]
    /// Dans l'ordre série, séances, premier mois ; une famille entièrement obtenue n'y figure plus.
    public var next: [Badge]

    public init(earned: [Badge], next: [Badge]) {
        self.earned = earned
        self.next = next
    }
}

/// Les badges de régularité, calculés depuis les séances et jamais stockés (spec M7 §13). Les semaines sont jugées avec
/// l'objectif d'aujourd'hui, comme la série (spec M7 §9).
public enum Badges {
    public static let streakGoals = [4, 8, 12, 26, 52]
    public static let sessionGoals = [10, 50, 100, 250, 500]
    public static let fullMonthWeeks = 4

    public static func make(sessions: [WorkoutSession], target: Int, historyStart: Date?, now: Date,
                            calendar: Calendar) -> BadgeShelf {
        let counted = sessions.filter(WeekStreak.counts).sorted { $0.startedAt < $1.startedAt }
        let weeks = successfulWeeks(counted: counted, target: target, historyStart: historyStart, now: now, calendar: calendar)
        let streak = WeekStreak.summary(sessions: sessions, target: target, historyStart: historyStart, now: now,
                                        calendar: calendar).streak

        let streakDates = streakEarnings(weeks)
        let sessionDates = Dictionary(uniqueKeysWithValues: sessionGoals.compactMap { goal in
            counted.count >= goal ? (goal, counted[goal - 1].startedAt) : nil
        })
        let month = monthProgress(weeks, calendar: calendar)

        var earned: [Badge] = []
        for goal in streakGoals {
            if let date = streakDates[goal] {
                earned.append(Badge(kind: .streak(weeks: goal), earnedAt: date, current: goal, goal: goal))
            }
        }
        for goal in sessionGoals {
            if let date = sessionDates[goal] {
                earned.append(Badge(kind: .sessions(count: goal), earnedAt: date, current: goal, goal: goal))
            }
        }
        if let date = month.earnedAt {
            earned.append(Badge(kind: .firstFullMonth, earnedAt: date, current: fullMonthWeeks, goal: fullMonthWeeks))
        }

        var next: [Badge] = []
        if let goal = streakGoals.first(where: { streakDates[$0] == nil }) {
            next.append(Badge(kind: .streak(weeks: goal), earnedAt: nil, current: streak, goal: goal))
        }
        if let goal = sessionGoals.first(where: { sessionDates[$0] == nil }) {
            next.append(Badge(kind: .sessions(count: goal), earnedAt: nil, current: counted.count, goal: goal))
        }
        if month.earnedAt == nil {
            next.append(Badge(kind: .firstFullMonth, earnedAt: nil, current: month.best, goal: fullMonthWeeks))
        }

        // Chronologique ; à date égale, l'ordre de construction (série, séances, mois).
        let chronological = earned.enumerated()
            .sorted { ($0.element.earnedAt ?? .distantPast, $0.offset) < ($1.element.earnedAt ?? .distantPast, $1.offset) }
            .map(\.element)
        return BadgeShelf(earned: chronological, next: next)
    }

    /// Une semaine réussie : son lundi et le début de la séance qui l'a fait atteindre l'objectif.
    private struct SuccessfulWeek {
        var monday: Date
        var reachedAt: Date
    }

    /// Les semaines de la semaine de `historyStart` à la semaine en cours, `nil` à la place d'une semaine manquée (la semaine en
    /// cours n'est réussie qu'une fois son objectif atteint). Vide sans début d'historique.
    private static func successfulWeeks(counted: [WorkoutSession], target: Int, historyStart: Date?, now: Date,
                                        calendar: Calendar) -> [SuccessfulWeek?] {
        guard let historyStart else { return [] }
        var perWeek = [Date: [Date]]()
        for session in counted {
            perWeek[WeekSchedule.weekStart(of: session.startedAt, calendar: calendar), default: []].append(session.startedAt)
        }
        let current = WeekSchedule.weekStart(of: now, calendar: calendar)
        var week = WeekSchedule.weekStart(of: historyStart, calendar: calendar)
        var weeks: [SuccessfulWeek?] = []
        while week <= current {
            let starts = perWeek[week] ?? []
            weeks.append(starts.count >= target ? SuccessfulWeek(monday: week, reachedAt: starts[target - 1]) : nil)
            guard let next = calendar.date(byAdding: .weekOfYear, value: 1, to: week), next > week else { break }
            week = next
        }
        return weeks
    }

    /// Pour chaque palier de série atteint, la date de la séance qui a fait réussir la semaine où la suite l'a atteint.
    private static func streakEarnings(_ weeks: [SuccessfulWeek?]) -> [Int: Date] {
        var dates: [Int: Date] = [:]
        var run = 0
        for week in weeks {
            guard let week else {
                run = 0
                continue
            }
            run += 1
            for goal in streakGoals where run >= goal && dates[goal] == nil { dates[goal] = week.reachedAt }
        }
        return dates
    }

    /// Le premier mois civil (celui du lundi de la semaine) à `fullMonthWeeks` semaines réussies, daté par la 4e ; sinon le
    /// meilleur nombre de semaines réussies dans un mois.
    private static func monthProgress(_ weeks: [SuccessfulWeek?], calendar: Calendar) -> (earnedAt: Date?, best: Int) {
        var perMonth: [DateComponents: [SuccessfulWeek]] = [:]
        var order: [DateComponents] = []
        for week in weeks.compactMap({ $0 }) {
            let month = calendar.dateComponents([.year, .month], from: week.monday)
            if perMonth[month] == nil { order.append(month) }
            perMonth[month, default: []].append(week)
        }
        let earnedAt = order.lazy.compactMap { month -> Date? in
            guard let weeks = perMonth[month], weeks.count >= fullMonthWeeks else { return nil }
            return weeks[fullMonthWeeks - 1].reachedAt
        }.first
        return (earnedAt, perMonth.values.map(\.count).max() ?? 0)
    }
}
