import Foundation

/// La régularité du coucher : l'écart moyen des heures d'endormissement à leur médiane. Pure, et jamais enregistrée (frontière M8).
public enum BedtimeRegularity {
    public static let windowNights = 14
    public static let minimumNights = 5
    private static let roundingMinutes = 5

    public enum Level: Sendable, Equatable {
        case regular, fairlyRegular, irregular
    }

    /// L'écart moyen à la médiane, en minutes arrondies à 5, sur un cadran qui commence à midi (23:30 et 00:30 sont à une heure l'un
    /// de l'autre, pas à 23 heures) ; `nil` sous `minimumNights` nuits.
    public static func minutes(fellAsleep: [Date], calendar: Calendar) -> Int? {
        guard fellAsleep.count >= minimumNights else { return nil }
        let times = fellAsleep.map { HabitualBedtime.dialMinutes($0, calendar: calendar) }.sorted()
        let middle = times.count / 2
        let median = times.count.isMultiple(of: 2)
            ? Double(times[middle - 1] + times[middle]) / 2
            : Double(times[middle])
        let meanGap = times.reduce(0.0) { $0 + abs(Double($1) - median) } / Double(times.count)
        return Int((meanGap / Double(roundingMinutes)).rounded()) * roundingMinutes
    }

    /// Régulier jusqu'à 30 min d'écart, assez régulier jusqu'à 60, irrégulier au-delà.
    public static func level(minutes: Int) -> Level {
        if minutes <= 30 { return .regular }
        return minutes <= 60 ? .fairlyRegular : .irregular
    }
}
