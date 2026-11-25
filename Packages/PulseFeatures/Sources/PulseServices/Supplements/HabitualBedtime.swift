import Foundation
import PulseDomain
import PulseRecoveryEngine

/// L'heure habituelle d'endormissement : la médiane des débuts de nuit des 14 dernières nuits. Pur : les heures viennent du
/// calendrier donné. Elle n'est jamais enregistrée, ni en local ni sur iCloud : recalculée à chaque planification depuis le cache
/// local d'Apple Santé, elle ne quitte pas l'iPhone (frontière M8).
public enum HabitualBedtime {
    /// Les nuits regardées : celles dont le réveil tombe dans les 14 derniers jours, aujourd'hui compris.
    public static let windowNights = 14
    /// Sous ce nombre de nuits, pas d'heure habituelle : le complément garde son heure fixe.
    public static let minimumNights = 5
    /// L'avance du rappel « au coucher » sur l'heure habituelle d'endormissement.
    public static let leadMinutes = 30
    /// La médiane est arrondie à 5 minutes.
    static let roundingMinutes = 5
    private static let dayMinutes = 24 * 60

    /// La médiane des heures d'endormissement, en minutes après minuit, arrondie à 5 minutes ; `nil` sous `minimumNights` nuits.
    /// Les heures sont lues sur un cadran qui commence à midi : 23:30 et 00:30 donnent minuit, pas midi.
    public static func minutes(fellAsleep: [Date], calendar: Calendar) -> Int? {
        guard fellAsleep.count >= minimumNights else { return nil }
        let unwrapped = fellAsleep.map { date -> Int in
            let parts = calendar.dateComponents([.hour, .minute], from: date)
            let minutes = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
            return minutes < dayMinutes / 2 ? minutes + dayMinutes : minutes
        }
        .sorted()
        let middle = unwrapped.count / 2
        let median = unwrapped.count.isMultiple(of: 2)
            ? Double(unwrapped[middle - 1] + unwrapped[middle]) / 2
            : Double(unwrapped[middle])
        let rounded = Int((median / Double(roundingMinutes)).rounded()) * roundingMinutes
        return rounded % dayMinutes
    }

    /// L'heure du rappel « au coucher » qui suit les nuits : `leadMinutes` avant l'heure habituelle, en minutes après minuit.
    public static func reminderMinutes(habitual: Int) -> Int {
        ((habitual - leadMinutes) % dayMinutes + dayMinutes) % dayMinutes
    }
}

/// Lit les heures d'endormissement des 14 dernières nuits dans le cache local d'Apple Santé. Ne lit jamais Apple Santé : le
/// passage du jour tient le cache à jour. Le début d'une nuit est celui de l'écran Nuit (`NightSleepBuilder`).
public struct HabitualBedtimeReader: Sendable {
    private let cache: any HealthSampleCache
    private let calendar: Calendar

    public init(cache: any HealthSampleCache, calendar: Calendar) {
        self.cache = cache
        self.calendar = calendar
    }

    /// Les débuts des nuits dont le réveil tombe dans les 14 derniers jours ; aucun si la lecture du cache échoue.
    public func fellAsleepTimes(now: Date) async -> [Date] {
        let today = calendar.startOfDay(for: now)
        // Une nuit commence la veille de son réveil : un jour de marge avant la plus ancienne.
        guard let start = calendar.date(byAdding: .day, value: -(HabitualBedtime.windowNights + 1), to: today),
              let end = calendar.date(byAdding: .day, value: 1, to: today),
              let cached = try? await cache.samples(kind: .sleep, from: start, to: end) else { return [] }
        let sleep = CachedSampleMapping.sleepIntervals(cached)
        let builder = NightSleepBuilder(calendar: calendar)
        return (0..<HabitualBedtime.windowNights).compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: today).flatMap { builder.night(for: $0, sleep: sleep)?.fellAsleep }
        }
    }

    /// L'heure habituelle d'endormissement, en minutes après minuit ; `nil` sous 5 nuits.
    public func minutes(now: Date) async -> Int? {
        HabitualBedtime.minutes(fellAsleep: await fellAsleepTimes(now: now), calendar: calendar)
    }
}
