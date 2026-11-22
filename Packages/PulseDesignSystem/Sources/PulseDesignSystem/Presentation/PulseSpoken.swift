import Foundation

/// Les textes lus par VoiceOver, en français, avec les nombres dits naturellement : jamais « kg », « min », « tiret » ni
/// d'abréviation de mois. Des fonctions pures ; chaque mot passe par le catalogue de chaînes, pour une version anglaise.
public enum PulseSpoken {
    /// « 0 série », « 1 série », « 2 séries » : le singulier jusqu'à 1, le pluriel au-delà. Sert aussi à l'affichage visible.
    public static func count(_ n: Int, singular: String, plural: String) -> String {
        let number = PulseFormat.grouped(Double(n), maxFractionDigits: 0)
        let word = abs(n) <= 1 ? singular : plural
        return String(localized: "\(number) \(word)", bundle: .module)
    }

    /// « 80 kilos », « 62,5 kilos », « 1 kilo », « 12 450 kilos ». Le singulier s'applique sous 2, comme en français, d'après
    /// la valeur arrondie telle qu'elle est dite : 1,996 donne « 2 kilos ».
    public static func kilos(_ kg: Double) -> String {
        let number = PulseFormat.grouped(kg, maxFractionDigits: 2)
        let spoken = (kg * 100).rounded() / 100
        return abs(spoken) < 2
            ? String(localized: "\(number) kilo", bundle: .module)
            : String(localized: "\(number) kilos", bundle: .module)
    }

    /// « 8,2 kilomètres », « 1,5 kilomètre », « 1 kilomètre ». Une décimale au plus ; le singulier s'applique sous 2, d'après la
    /// valeur arrondie telle qu'elle est dite : 1,96 donne « 2 kilomètres ». L'arrondi au pair le plus proche est celui des
    /// formateurs qui affichent la distance : 1,45 km s'affiche « 1,4 km » et se dit « 1,4 kilomètre ».
    public static func kilometres(_ km: Double) -> String {
        let rounded = (km * 10).rounded(.toNearestOrEven) / 10
        let number = PulseFormat.grouped(rounded, maxFractionDigits: 1)
        return abs(rounded) < 2
            ? String(localized: "\(number) kilomètre", bundle: .module)
            : String(localized: "\(number) kilomètres", bundle: .module)
    }

    /// « 1 répétition », « 8 répétitions ».
    public static func repetitions(_ n: Int) -> String {
        count(n, singular: String(localized: "répétition", bundle: .module), plural: String(localized: "répétitions", bundle: .module))
    }

    /// « 45 secondes », « 1 minute 30 », « 2 heures 5 minutes », « 1 heure 45 minutes 7 ». Les secondes qui suivent des
    /// minutes se disent sans unité ; l'unité reste quand rien ne les précède ou qu'elles suivent des heures seules.
    public static func duration(seconds: Int) -> String {
        let total = max(0, seconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let rest = total % 60
        var parts: [String] = []
        if hours > 0 { parts.append(hoursText(hours)) }
        if minutes > 0 { parts.append(minutesText(minutes)) }
        if rest > 0 {
            parts.append(minutes > 0 ? "\(rest)" : secondsText(rest))
        }
        return parts.isEmpty ? secondsText(0) : parts.joined(separator: " ")
    }

    /// « 5 minutes 29 par kilomètre ».
    public static func pace(secondsPerKilometer: Int) -> String {
        String(localized: "\(duration(seconds: secondsPerKilometer)) par kilomètre", bundle: .module)
    }

    /// « 8 heures », « 8 heures 30 ».
    public static func clock(hour: Int, minute: Int) -> String {
        let hours = hoursText(hour)
        return minute == 0 ? hours : String(localized: "\(hours) \(minute)", bundle: .module)
    }

    /// « 9 sur 12 ».
    public static func outOf(_ value: Int, _ total: Int) -> String {
        String(localized: "\(value) sur \(total)", bundle: .module)
    }

    /// « 28 octobre » : le jour et le mois en toutes lettres.
    public static func date(_ date: Date, calendar: Calendar) -> String {
        formatted(date, calendar: calendar, format: "d MMMM")
    }

    /// « lundi ».
    public static func weekday(_ date: Date, calendar: Calendar) -> String {
        formatted(date, calendar: calendar, format: "EEEE")
    }

    private static func hoursText(_ value: Int) -> String {
        value <= 1 ? String(localized: "\(value) heure", bundle: .module) : String(localized: "\(value) heures", bundle: .module)
    }

    private static func minutesText(_ value: Int) -> String {
        value <= 1
            ? String(localized: "\(value) minute", bundle: .module)
            : String(localized: "\(value) minutes", bundle: .module)
    }

    private static func secondsText(_ value: Int) -> String {
        value <= 1
            ? String(localized: "\(value) seconde", bundle: .module)
            : String(localized: "\(value) secondes", bundle: .module)
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
