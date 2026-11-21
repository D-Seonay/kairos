import Foundation
import PulseDesignSystem
import PulseServices

/// Les formats français des cinq vues Stats : `PulseFormat` pour les nombres et les durées, les temps de course en plus.
enum StatsText {
    /// Une valeur impossible à afficher (non finie, négative) donne « — », comme `PulseFormat`.
    private static let dash = "\u{2014}"

    /// « 2 140 », « 91 200 » : milliers séparés d'une espace fine insécable, sans décimale (comme `PlanningText.tonnage`).
    static func number(_ value: Double) -> String {
        guard value.isFinite else { return dash }
        return value.formatted(.number.precision(.fractionLength(0)).locale(Locale(identifier: "fr_FR")))
    }

    /// « +6 % », « −4 % » ; `nil` sans période précédente de comparaison.
    static func change(_ comparison: StatsComparison?) -> String? {
        comparison?.change.map { PulseFormat.signedPercent($0 * 100) }
    }

    /// « 7 h 12 », « 45 min » : des minutes, arrondies.
    static func duration(minutes: Double) -> String {
        guard minutes.isFinite, minutes >= 0, minutes < 1e12 else { return dash }
        return PulseFormat.duration(minutes: Int(minutes.rounded()))
    }

    /// « 24:31 », « 1:45:07 » : un temps de course.
    static func raceTime(seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0, seconds < 1e12 else { return dash }
        let total = Int(seconds.rounded())
        let hours = total / 3_600
        let minutes = total % 3_600 / 60
        let rest = total % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, rest)
            : String(format: "%d:%02d", minutes, rest)
    }

    /// « 24 novembre » (`month: .wide`) ou « 24 nov. » (`.abbreviated`), dans le fuseau du calendrier.
    static func dayMonth(_ date: Date, calendar: Calendar, month: Date.FormatStyle.Symbol.Month = .wide) -> String {
        var style = Date.FormatStyle.dateTime.day().month(month)
        style.locale = Locale(identifier: "fr_FR")
        style.calendar = calendar
        style.timeZone = calendar.timeZone
        return date.formatted(style)
    }

    /// « 64,3 km ».
    static func kilometers(meters: Double) -> String {
        guard meters.isFinite, meters >= 0 else { return dash }
        let km = (meters / 1000).formatted(.number.precision(.fractionLength(1)).locale(Locale(identifier: "fr_FR")))
        return String(localized: "\(km) km", bundle: .module)
    }

    /// « 4:54 /km ».
    static func pace(secondsPerKm: Double) -> String {
        guard secondsPerKm.isFinite, secondsPerKm >= 0, secondsPerKm < 1e12 else { return dash }
        let total = Int(secondsPerKm.rounded())
        return String(format: "%d:%02d /km", total / 60, total % 60)
    }
}
