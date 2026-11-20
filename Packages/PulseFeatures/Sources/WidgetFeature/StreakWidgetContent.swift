import Foundation
import PulseDesignSystem
import PulseDomain

/// Les données affichées par le widget Série (streak) : semaine en cours, pastilles des jours et total de semaines.
public struct StreakWidgetContent: Sendable, Equatable {
    public static let kind = "StreakWidget"

    public static var displayName: String {
        String(localized: "Série", bundle: .module)
    }

    public static var summary: String {
        String(localized: "Ton rythme d'entraînement et ta régularité.", bundle: .module)
    }

    public enum DayState: Sendable, Equatable {
        case completed
        case rest
        case today
        case upcoming
    }

    public var streakWeeks: Int
    public var completedThisWeek: Int
    public var targetThisWeek: Int
    public var weekDays: [DayState]
    public var subtitle: String
    public var inlineText: String
    public var accessibilityLabel: String

    public init(
        streakWeeks: Int,
        completedThisWeek: Int,
        targetThisWeek: Int,
        weekDays: [DayState],
        subtitle: String,
        inlineText: String,
        accessibilityLabel: String
    ) {
        self.streakWeeks = streakWeeks
        self.completedThisWeek = completedThisWeek
        self.targetThisWeek = targetThisWeek
        self.weekDays = weekDays
        self.subtitle = subtitle
        self.inlineText = inlineText
        self.accessibilityLabel = accessibilityLabel
    }

    /// La série et la semaine de l'instantané du jour ; l'exemple sans instantané du jour ou sans série.
    public static func make(snapshot: WidgetSnapshot?, at date: Date, calendar: Calendar) -> StreakWidgetContent {
        guard let planning = WidgetPlanningText.planning(snapshot, at: date, calendar: calendar) else {
            return sample(at: date, calendar: calendar)
        }
        let streak = planning.streak
        return content(weeks: streak.weeks, completed: streak.completed, target: streak.target,
                       days: planning.week.map(WidgetPlanningText.state(of:)))
    }

    public static func sample(at date: Date, calendar: Calendar) -> StreakWidgetContent {
        content(weeks: 14, completed: 3, target: 5, days: [.completed, .completed, .completed, .rest, .today, .upcoming, .rest])
    }

    private static func content(weeks: Int, completed: Int, target: Int, days: [DayState]) -> StreakWidgetContent {
        let subtitleText = String(localized: "\(completed) sur \(target) cette semaine", bundle: .module)
        let inline = String(localized: "\(weeks) sem. · \(completed)/\(target)", bundle: .module)
        let label = String(localized: "Série de \(weeks) semaines, \(completed) séances sur \(target) cette semaine", bundle: .module)
        return StreakWidgetContent(
            streakWeeks: weeks,
            completedThisWeek: completed,
            targetThisWeek: target,
            weekDays: days,
            subtitle: subtitleText,
            inlineText: inline,
            accessibilityLabel: label
        )
    }
}
