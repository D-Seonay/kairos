import Foundation
import PulseDesignSystem
import PulseDomain

/// Les données affichées par le grand widget Semaine : progression de la semaine, séance du jour,
/// charge d'entraînement (ACWR) et prochaine séance.
public struct WeekWidgetContent: Sendable, Equatable {
    public static let kind = "WeekWidget"

    public static var displayName: String {
        String(localized: "Cette semaine", bundle: .module)
    }

    public static var summary: String {
        String(localized: "Ton planning de la semaine, la séance du jour et ta charge.", bundle: .module)
    }

    public struct DayItem: Sendable, Equatable {
        public var letter: String
        public var iconName: String
        public var isRest: Bool
        public var state: StreakWidgetContent.DayState

        public init(letter: String, iconName: String, isRest: Bool, state: StreakWidgetContent.DayState) {
            self.letter = letter
            self.iconName = iconName
            self.isRest = isRest
            self.state = state
        }
    }

    public var badgeText: String
    public var days: [DayItem]
    public var todayTitle: String
    public var todayMeta: String
    public var todayMuscleLevels: [MuscleMapRegion: Int]
    public var acwrRatio: Double
    public var acwrZoneText: String
    public var tomorrowText: String
    public var accessibilityLabel: String

    public init(
        badgeText: String,
        days: [DayItem],
        todayTitle: String,
        todayMeta: String,
        todayMuscleLevels: [MuscleMapRegion: Int],
        acwrRatio: Double,
        acwrZoneText: String,
        tomorrowText: String,
        accessibilityLabel: String
    ) {
        self.badgeText = badgeText
        self.days = days
        self.todayTitle = todayTitle
        self.todayMeta = todayMeta
        self.todayMuscleLevels = todayMuscleLevels
        self.acwrRatio = acwrRatio
        self.acwrZoneText = acwrZoneText
        self.tomorrowText = tomorrowText
        self.accessibilityLabel = accessibilityLabel
    }

    public static func make(snapshot: WidgetSnapshot?, at date: Date, calendar: Calendar) -> WeekWidgetContent {
        sample(at: date, calendar: calendar)
    }

    public static func sample(at date: Date, calendar: Calendar) -> WeekWidgetContent {
        let dayItems: [DayItem] = [
            DayItem(letter: "L", iconName: "dumbbell.fill", isRest: false, state: .completed),
            DayItem(letter: "M", iconName: "figure.run", isRest: false, state: .completed),
            DayItem(letter: "M", iconName: "dumbbell.fill", isRest: false, state: .completed),
            DayItem(letter: "J", iconName: "minus", isRest: true, state: .rest),
            DayItem(letter: "V", iconName: "dumbbell.fill", isRest: false, state: .today),
            DayItem(letter: "S", iconName: "figure.run", isRest: false, state: .upcoming),
            DayItem(letter: "D", iconName: "minus", isRest: true, state: .rest)
        ]

        let title = String(localized: "Pectoraux et triceps", bundle: .module)
        let meta = String(localized: "14 séries · ajustée, RPE 7,5", bundle: .module)
        let acwr = String(localized: "1,12 · zone optimale", bundle: .module)
        let tomorrow = String(localized: "Demain : endurance 45 min, zone 2", bundle: .module)
        let badge = String(localized: "3 sur 5", bundle: .module)
        let spoken = String(
            localized: "Cette semaine : 3 séances sur 5 faites. Aujourd'hui : \(title). Charge 1,12 en zone optimale. \(tomorrow)",
            bundle: .module
        )

        return WeekWidgetContent(
            badgeText: badge,
            days: dayItems,
            todayTitle: title,
            todayMeta: meta,
            todayMuscleLevels: [.chest: 4, .triceps: 3, .frontDeltoid: 2],
            acwrRatio: 1.12,
            acwrZoneText: acwr,
            tomorrowText: tomorrow,
            accessibilityLabel: spoken
        )
    }
}
