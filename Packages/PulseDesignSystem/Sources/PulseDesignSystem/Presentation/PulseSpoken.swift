import Foundation

/// Les textes lus par VoiceOver, en français, avec les nombres dits naturellement : jamais « kg », « min », « tiret » ni
/// d'abréviation de mois. Des fonctions pures, sans bibliothèque de localisation : la langue de l'app est le français.
public enum PulseSpoken {
    /// « 0 série », « 1 série », « 2 séries » : le singulier jusqu'à 1, le pluriel au-delà. Sert aussi à l'affichage visible.
    public static func count(_ n: Int, singular: String, plural: String) -> String {
        "\(PulseFormat.grouped(Double(n), maxFractionDigits: 0)) \(abs(n) <= 1 ? singular : plural)"
    }

    /// « 80 kilos », « 62,5 kilos », « 1 kilo », « 12 450 kilos ». Le singulier s'applique sous 2, comme en français.
    public static func kilos(_ kg: Double) -> String {
        "\(PulseFormat.grouped(kg, maxFractionDigits: 2)) \(abs(kg) < 2 ? "kilo" : "kilos")"
    }

    /// « 45 secondes », « 1 minute 30 », « 2 heures 5 minutes », « 1 heure 45 minutes 7 ». Les secondes qui suivent des
    /// minutes se disent sans unité ; l'unité reste quand rien ne les précède ou qu'elles suivent des heures seules.
    public static func duration(seconds: Int) -> String {
        let total = max(0, seconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let rest = total % 60
        var parts: [String] = []
        if hours > 0 { parts.append(unit(hours, "heure", "heures")) }
        if minutes > 0 { parts.append(unit(minutes, "minute", "minutes")) }
        if rest > 0 {
            parts.append(minutes > 0 ? "\(rest)" : unit(rest, "seconde", "secondes"))
        }
        return parts.isEmpty ? "0 seconde" : parts.joined(separator: " ")
    }

    /// « 5 minutes 29 par kilomètre ».
    public static func pace(secondsPerKilometer: Int) -> String {
        "\(duration(seconds: secondsPerKilometer)) par kilomètre"
    }

    /// « 8 heures », « 8 heures 30 ».
    public static func clock(hour: Int, minute: Int) -> String {
        let hours = unit(hour, "heure", "heures")
        return minute == 0 ? hours : "\(hours) \(minute)"
    }

    /// « 9 sur 12 ».
    public static func outOf(_ value: Int, _ total: Int) -> String {
        "\(value) sur \(total)"
    }

    /// « 28 octobre » : le jour et le mois en toutes lettres.
    public static func date(_ date: Date, calendar: Calendar) -> String {
        formatted(date, calendar: calendar, format: "d MMMM")
    }

    /// « lundi ».
    public static func weekday(_ date: Date, calendar: Calendar) -> String {
        formatted(date, calendar: calendar, format: "EEEE")
    }

    private static func unit(_ value: Int, _ singular: String, _ plural: String) -> String {
        "\(value) \(value <= 1 ? singular : plural)"
    }

    private static func formatted(_ date: Date, calendar: Calendar, format: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = format
        return formatter.string(from: date)
    }
}
