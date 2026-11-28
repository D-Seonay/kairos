import Foundation

/// La clé civile d'un jour, « 2026-11-27 » : la même à Paris et à New York, contrairement à minuit local. Les lignes « une par
/// jour » (scores, check-ins, lectures de nuit) se retrouvent par elle ; leur `day` reste minuit du calendrier qui l'a écrite.
public enum DayKey {
    /// La plus grande différence entre deux fuseaux (UTC−12 à UTC+14) est de 26 h : une fenêtre de 36 h autour de minuit local
    /// contient le minuit de n'importe quel fuseau pour le même jour civil.
    static let window: TimeInterval = 36 * 3_600

    /// « 2026-11-27 » pour `date` lue dans le fuseau de `calendar`, toujours en grégorien : un iPhone réglé sur le calendrier
    /// bouddhiste (Réglages > Calendrier) écrit la même clé qu'un iPad grégorien.
    public static func key(for date: Date, calendar: Calendar) -> String {
        let gregorian = gregorian(in: calendar)
        let parts = gregorian.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// Minuit de ce jour civil (grégorien) dans le fuseau de `calendar` ; `nil` pour une clé illisible.
    public static func date(for key: String, calendar: Calendar) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        let gregorian = gregorian(in: calendar)
        let components = DateComponents(year: parts[0], month: parts[1], day: parts[2])
        return gregorian.date(from: components).map { gregorian.startOfDay(for: $0) }
    }

    /// Le calendrier grégorien du fuseau de `calendar`, dans lequel toutes les clés s'écrivent et se lisent.
    private static func gregorian(in calendar: Calendar) -> Calendar {
        if calendar.identifier == .gregorian { return calendar }
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = calendar.timeZone
        gregorian.locale = Locale(identifier: "en_US_POSIX")
        return gregorian
    }

    /// La clé enregistrée ; pour une ligne écrite avant la V9 (ou par une version plus ancienne de l'app, sur un autre appareil),
    /// celle que son `day`, minuit du fuseau qui l'a écrite, désigne. Minuit de `calendar` : le jour de `calendar`. Sinon la ligne
    /// vient d'un autre fuseau, inconnu : le jour dont le minuit UTC est le plus proche, juste pour tout fuseau de UTC−11 à UTC+11
    /// (minuit à Paris, le 27, c'est le 26 à 18 h à New York : le jour de New York serait le 26). Cette estimation se trompe
    /// au-delà (Auckland en été, Samoa, Tonga) : elle sert à lire, jamais à enregistrer une clé ni à retirer un doublon.
    static func effective(_ stored: String?, day: Date, calendar: Calendar) -> String {
        exact(stored, day: day, calendar: calendar) ?? key(for: day.addingTimeInterval(12 * 3_600), calendar: utc)
    }

    /// La clé enregistrée, ou celle d'une ligne écrite à minuit pile de `calendar` ; `nil` quand il faudrait l'estimer.
    static func exact(_ stored: String?, day: Date, calendar: Calendar) -> String? {
        if let stored { return stored }
        return calendar.startOfDay(for: day) == day ? key(for: day, calendar: calendar) : nil
    }

    private static let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }()

    /// Les instants à lire pour couvrir les jours civils de `[from, to)` quel que soit le fuseau qui les a écrits.
    static func widened(from: Date, to: Date) -> (from: Date, to: Date) {
        (from.addingTimeInterval(-window), to.addingTimeInterval(window))
    }
}
