import Foundation

/// La clé civile d'un jour, « 2026-11-27 » : la même à Paris et à New York, contrairement à minuit local. Les lignes « une par
/// jour » (scores, check-ins, lectures de nuit) se retrouvent par elle ; leur `day` reste minuit du calendrier qui l'a écrite.
public enum DayKey {
    /// La plus grande différence entre deux fuseaux (UTC−12 à UTC+14) est de 26 h : une fenêtre de 36 h autour de minuit local
    /// contient le minuit de n'importe quel fuseau pour le même jour civil.
    static let window: TimeInterval = 36 * 3_600

    /// « 2026-11-27 » pour `date` lue dans `calendar`.
    public static func key(for date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// Minuit de ce jour civil dans `calendar` ; `nil` pour une clé illisible.
    public static func date(for key: String, calendar: Calendar) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        let components = DateComponents(year: parts[0], month: parts[1], day: parts[2])
        return calendar.date(from: components).map { calendar.startOfDay(for: $0) }
    }

    /// La clé enregistrée, ou celle de `day` lue dans `calendar` pour une ligne écrite avant la V9 (ou par une version plus ancienne
    /// de l'app, sur un autre appareil).
    static func effective(_ stored: String?, day: Date, calendar: Calendar) -> String {
        stored ?? key(for: day, calendar: calendar)
    }

    /// Les instants à lire pour couvrir les jours civils de `[from, to)` quel que soit le fuseau qui les a écrits.
    static func widened(from: Date, to: Date) -> (from: Date, to: Date) {
        (from.addingTimeInterval(-window), to.addingTimeInterval(window))
    }
}
