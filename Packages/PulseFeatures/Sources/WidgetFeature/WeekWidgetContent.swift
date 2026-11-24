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
    /// La silhouette de la carte, celle du profil quand l'instantané la donne.
    public var muscleMapFigure: MuscleMapFigure

    public init(
        badgeText: String,
        days: [DayItem],
        todayTitle: String,
        todayMeta: String,
        todayMuscleLevels: [MuscleMapRegion: Int],
        acwrRatio: Double,
        acwrZoneText: String,
        tomorrowText: String,
        accessibilityLabel: String,
        muscleMapFigure: MuscleMapFigure = .female
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
        self.muscleMapFigure = muscleMapFigure
    }

    /// « Cette semaine : 3 séances faites sur 5. Lundi fait, … Aujourd'hui : Push. Charge 1,12, zone optimale. Demain, Fractionné » :
    /// les nombres avec leurs mots, l'état des jours, sans point médian.
    static func spokenLabel(week: String, title: String, load: String, next: String) -> String {
        String(localized: "\(week) Aujourd'hui : \(title). Charge \(load). \(next)", bundle: .module)
    }

    /// « Cette semaine : 3 séances faites sur 5. Lundi fait, mardi fait… », les jours quand on les connaît.
    static func spokenWeek(completed: Int, target: Int, days: String) -> String {
        let sessions = PulseSpoken.count(completed, singular: String(localized: "séance faite", bundle: .module),
                                         plural: String(localized: "séances faites", bundle: .module))
        let summary = String(localized: "Cette semaine : \(sessions) sur \(target).", bundle: .module)
        return days.isEmpty ? summary : "\(summary) \(days)."
    }

    /// La semaine, la séance du jour, la charge et la prochaine séance de l'instantané du jour. Sans instantané du jour ou sans
    /// semaine, le widget le dit au lieu d'inventer une semaine.
    public static func make(snapshot: WidgetSnapshot?, at date: Date, calendar: Calendar) -> WeekWidgetContent {
        guard let planning = WidgetPlanningText.planning(snapshot, at: date, calendar: calendar) else {
            return notReady(at: date, calendar: calendar)
        }
        let snapshot = planning.snapshot
        let days = planning.week.map { day in
            DayItem(letter: WidgetPlanningText.letter(of: day, calendar: calendar), iconName: WidgetPlanningText.icon(of: day.kind),
                    isRest: day.kind == .rest, state: WidgetPlanningText.state(of: day))
        }
        let title = snapshot.sessionTitle ?? String(localized: "Jour de repos", bundle: .module)
        let meta = snapshot.sessionTitle == nil ? String(localized: "Récupération", bundle: .module)
            : snapshot.isLightened ? String(localized: "Allégée selon ta forme", bundle: .module)
            : String(localized: "Comme prévu", bundle: .module)
        var load = String(localized: "après 28 jours", bundle: .module)
        var spokenLoad = load
        if let ratio = snapshot.loadRatio {
            let reading = WidgetPlanningText.ratio(ratio)
            let zone = WidgetPlanningText.zone(of: ratio).text.lowercased()
            load = "\(reading) · \(zone)"
            spokenLoad = "\(reading), \(zone)"
        }
        let next = snapshot.nextSession.map { next in
            "\(WidgetPlanningText.timing(of: next.date, from: date, calendar: calendar)) : \(next.title)"
        } ?? String(localized: "Rien de prévu cette semaine", bundle: .module)
        let spokenNext = snapshot.nextSession.map { next in
            "\(WidgetPlanningText.timing(of: next.date, from: date, calendar: calendar)), \(next.title)"
        } ?? next
        let completed = planning.streak.completed
        let target = planning.streak.target
        let spokenDays = WidgetPlanningText.spokenWeek(planning.week, calendar: calendar)
        let spoken = spokenLabel(week: spokenWeek(completed: completed, target: target, days: spokenDays), title: title,
                                 load: spokenLoad, next: spokenNext)
        return WeekWidgetContent(
            badgeText: String(localized: "\(completed) sur \(target)", bundle: .module), days: days, todayTitle: title,
            todayMeta: meta, todayMuscleLevels: snapshot.sessionTitle.map(TodaySessionWidgetContent.defaultMuscleLevels(for:)) ?? [:],
            acwrRatio: snapshot.loadRatio ?? 1, acwrZoneText: load, tomorrowText: next, accessibilityLabel: spoken,
            muscleMapFigure: snapshot.muscleMapFigure ?? .female)
    }

    /// Pas encore d'instantané du jour : les sept jours de la vraie semaine, vides, aujourd'hui marqué, et une invitation à ouvrir
    /// l'app ; ni séance, ni charge, ni série inventées.
    static func notReady(at date: Date, calendar: Calendar) -> WeekWidgetContent {
        let days = WidgetPlanningText.weekDates(containing: date, calendar: calendar).map { day in
            let isToday = calendar.isDate(day, inSameDayAs: date)
            let widgetDay = WidgetDay(date: day, kind: .rest, state: .rest, isToday: isToday)
            return DayItem(letter: WidgetPlanningText.letter(of: widgetDay, calendar: calendar), iconName: "minus", isRest: false,
                           state: isToday ? .today : .upcoming)
        }
        let spoken = String(localized: "Cette semaine : pas encore prête. Ouvre Pulse pour la mettre à jour", bundle: .module)
        return WeekWidgetContent(
            badgeText: PulseFormat.dash, days: days, todayTitle: String(localized: "Pas encore prête", bundle: .module),
            todayMeta: String(localized: "Ouvre Pulse pour la mettre à jour", bundle: .module), todayMuscleLevels: [:],
            acwrRatio: 1, acwrZoneText: PulseFormat.dash, tomorrowText: PulseFormat.dash, accessibilityLabel: spoken)
    }

    /// Un exemple, pour la galerie de widgets et le gabarit avant le premier chargement.
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
        let days = WidgetPlanningText.spokenWeek(WidgetPlanningText.sampleWeek(containing: date, calendar: calendar), calendar: calendar)
        let spoken = spokenLabel(
            week: spokenWeek(completed: 3, target: 5, days: days), title: title,
            load: String(localized: "1,12, zone optimale", bundle: .module),
            next: String(localized: "Demain, endurance 45 minutes, zone 2", bundle: .module)
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
