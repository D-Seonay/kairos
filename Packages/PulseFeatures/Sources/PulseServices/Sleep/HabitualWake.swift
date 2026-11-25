import Foundation
import PulseDomain

/// L'heure habituelle de réveil : la médiane des réveils des 14 dernières nuits, semaine et week-end à part. Pure, et jamais
/// enregistrée : recalculée depuis le cache local d'Apple Santé, elle ne quitte pas l'iPhone (frontière M8). Une nuit est
/// rattachée au jour de son réveil, avant midi : pas besoin du cadran qui commence à midi, des minutes après minuit suffisent.
public enum HabitualWake {
    /// Sous ce nombre de nuits, un groupe (semaine ou week-end) prend la médiane de toutes les nuits.
    public static let groupMinimumNights = 3
    /// Sous ce nombre de nuits en tout, pas d'heure habituelle.
    public static let minimumNights = 5
    private static let roundingMinutes = 5

    /// La médiane, arrondie à 5 minutes, des réveils du groupe demandé (week-end : samedi et dimanche, d'après le jour du réveil) ;
    /// un groupe de moins de `groupMinimumNights` nuits prend la médiane de toutes les nuits, qui en demande `minimumNights` ;
    /// sinon `nil`.
    public static func minutes(wokeUp: [Date], weekend: Bool, calendar: Calendar) -> Int? {
        let all = wokeUp.map { (date: $0, minutes: clockMinutes($0, calendar: calendar)) }
        let group = all.filter { isWeekend($0.date, calendar: calendar) == weekend }.map(\.minutes)
        if group.count >= groupMinimumNights { return median(group) }
        guard all.count >= minimumNights else { return nil }
        return median(all.map(\.minutes))
    }

    private static func isWeekend(_ date: Date, calendar: Calendar) -> Bool {
        let weekday = Weekday(date: date, calendar: calendar)
        return weekday == .saturday || weekday == .sunday
    }

    private static func clockMinutes(_ date: Date, calendar: Calendar) -> Int {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }

    private static func median(_ values: [Int]) -> Int {
        let sorted = values.sorted()
        let middle = sorted.count / 2
        let median = sorted.count.isMultiple(of: 2)
            ? Double(sorted[middle - 1] + sorted[middle]) / 2
            : Double(sorted[middle])
        return Int((median / Double(roundingMinutes)).rounded()) * roundingMinutes
    }
}
