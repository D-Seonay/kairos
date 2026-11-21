import Foundation

/// La période commune des vues Stats : une fenêtre glissante qui finit aujourd'hui inclus (spec M7 §5).
public enum StatsPeriod: String, CaseIterable, Sendable, Identifiable {
    case week
    case month
    case quarter
    case year

    public var id: String { rawValue }

    public var days: Int {
        switch self {
        case .week: 7
        case .month: 30
        case .quarter: 90
        case .year: 365
        }
    }

    public var title: String {
        switch self {
        case .week: String(localized: "7 jours", bundle: .module)
        case .month: String(localized: "30 jours", bundle: .module)
        case .quarter: String(localized: "90 jours", bundle: .module)
        case .year: String(localized: "1 an", bundle: .module)
        }
    }

    /// Du début du jour `now − days + 1` au début de demain. Les bornes se calculent en jours de calendrier : un changement
    /// d'heure ne décale ni ne raccourcit la fenêtre.
    public func interval(now: Date, calendar: Calendar) -> DateInterval {
        let today = calendar.startOfDay(for: now)
        let start = calendar.date(byAdding: .day, value: -(days - 1), to: today) ?? today
        let end = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        return DateInterval(start: start, end: max(start, end))
    }

    /// Les `days` jours juste avant la période.
    public func previousInterval(now: Date, calendar: Calendar) -> DateInterval {
        let start = interval(now: now, calendar: calendar).start
        let previousStart = calendar.date(byAdding: .day, value: -days, to: start) ?? start
        return DateInterval(start: previousStart, end: start)
    }

    /// Le grain des courbes : un point par jour, par semaine sur un an pour garder la courbe lisible.
    public var chartBucket: StatsBucket { self == .year ? .week : .day }

    /// Le grain des barres de charge : par jour sur 7 jours, par semaine au-delà.
    public var loadBucket: StatsBucket { self == .week ? .day : .week }
}

/// Un regroupement de jours : le jour, ou la semaine qui commence le lundi (`WeekSchedule.weekStart`).
public enum StatsBucket: Sendable {
    case day
    case week
}

public struct StatsPoint: Sendable, Equatable, Identifiable {
    public var date: Date
    public var value: Double

    public var id: Date { date }

    public init(date: Date, value: Double) {
        self.date = date
        self.value = value
    }
}

/// Une valeur et la même sur la période précédente, pour les tuiles « +4 % vs 30 j précédents ».
public struct StatsComparison: Sendable, Equatable {
    public var value: Double
    public var previous: Double?

    /// L'évolution relative ; `nil` sans période précédente ou quand celle-ci vaut 0.
    public var change: Double? {
        guard let previous, previous != 0 else { return nil }
        return (value - previous) / previous
    }

    public init(value: Double, previous: Double?) {
        self.value = value
        self.previous = previous
    }
}
