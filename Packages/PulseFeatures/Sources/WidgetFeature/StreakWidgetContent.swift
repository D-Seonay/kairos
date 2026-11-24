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
    /// Faux sans instantané du jour : le widget montre un tiret au lieu d'un nombre de semaines.
    public var isReady: Bool

    public init(
        streakWeeks: Int,
        completedThisWeek: Int,
        targetThisWeek: Int,
        weekDays: [DayState],
        subtitle: String,
        inlineText: String,
        accessibilityLabel: String,
        isReady: Bool = true
    ) {
        self.streakWeeks = streakWeeks
        self.completedThisWeek = completedThisWeek
        self.targetThisWeek = targetThisWeek
        self.weekDays = weekDays
        self.subtitle = subtitle
        self.inlineText = inlineText
        self.accessibilityLabel = accessibilityLabel
        self.isReady = isReady
    }

    /// Le nombre de semaines affiché : un tiret tant que la série n'est pas chargée.
    public var weeksText: String {
        isReady ? "\(streakWeeks)" : PulseFormat.dash
    }

    /// La série et la semaine de l'instantané du jour. Sans instantané du jour ou sans série, le widget le dit au lieu d'inventer
    /// une série.
    public static func make(snapshot: WidgetSnapshot?, at date: Date, calendar: Calendar) -> StreakWidgetContent {
        guard let planning = WidgetPlanningText.planning(snapshot, at: date, calendar: calendar) else { return notReady }
        let streak = planning.streak
        return content(weeks: streak.weeks, completed: streak.completed, target: streak.target,
                       days: planning.week.map(WidgetPlanningText.state(of:)),
                       spokenDays: spokenDays(of: planning.week, calendar: calendar))
    }

    /// Pas encore d'instantané du jour : ni semaines ni pastilles inventées, une invitation à ouvrir l'app.
    static var notReady: StreakWidgetContent {
        StreakWidgetContent(
            streakWeeks: 0, completedThisWeek: 0, targetThisWeek: 0, weekDays: [],
            subtitle: String(localized: "Ouvre Pulse pour la mettre à jour", bundle: .module),
            inlineText: String(localized: "Série pas encore prête", bundle: .module),
            accessibilityLabel: String(localized: "Série pas encore prête. Ouvre Pulse pour la mettre à jour", bundle: .module),
            isReady: false)
    }

    /// Un exemple, pour la galerie de widgets et le gabarit avant le premier chargement.
    public static func sample(at date: Date, calendar: Calendar) -> StreakWidgetContent {
        let week = WidgetPlanningText.sampleWeek(containing: date, calendar: calendar)
        return content(weeks: 14, completed: 3, target: 5, days: week.map(WidgetPlanningText.state(of:)),
                       spokenDays: WidgetPlanningText.spokenWeek(week, calendar: calendar))
    }

    /// « Série de 14 semaines, 3 séances sur 5 cette semaine. Lundi fait, mardi fait… » : les nombres avec leurs mots, puis l'état
    /// des jours quand on le connaît.
    static func spokenLabel(weeks: Int, completed: Int, target: Int, week: String) -> String {
        let weeksText = PulseSpoken.count(weeks, singular: String(localized: "semaine", bundle: .module),
                                          plural: String(localized: "semaines", bundle: .module))
        let sessionsText = PulseSpoken.count(completed, singular: String(localized: "séance", bundle: .module),
                                             plural: String(localized: "séances", bundle: .module))
        let summary = String(localized: "Série de \(weeksText), \(sessionsText) sur \(target) cette semaine", bundle: .module)
        return week.isEmpty ? summary : "\(summary). \(week)"
    }

    private static func spokenDays(of week: [WidgetDay], calendar: Calendar) -> String {
        WidgetPlanningText.spokenWeek(week, calendar: calendar)
    }

    private static func content(weeks: Int, completed: Int, target: Int, days: [DayState], spokenDays: String) -> StreakWidgetContent {
        let subtitleText = String(localized: "\(completed) sur \(target) cette semaine", bundle: .module)
        let inline = String(localized: "\(weeks) sem. · \(completed)/\(target)", bundle: .module)
        let label = spokenLabel(weeks: weeks, completed: completed, target: target,
                                week: spokenDays)
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
