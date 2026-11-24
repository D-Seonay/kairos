import Foundation
import PulseDomain

/// La fenêtre d'une nuit et le filtre des intervalles qu'elle retient, partagés par `NightAggregator` (le score) et
/// `NightSleepBuilder` (l'écran Nuit) pour qu'ils ne divergent jamais.
enum NightWindow {
    /// Début de la fenêtre candidate de la nuit, en heures avant minuit du jour de réveil (18 h la veille).
    static let startHours = -6
    /// Fin de la fenêtre candidate, en heures après minuit (midi).
    static let endHours = 12

    /// Les intervalles endormis de la nuit de `day` (minuit local du jour de réveil) : ceux dont la fin tombe dans la fenêtre.
    static func retainedAsleep(for day: Date, in sleep: [SleepInterval], calendar: Calendar) -> [SleepInterval] {
        let start = hours(startHours, from: day, calendar: calendar)
        let end = hours(endHours, from: day, calendar: calendar)
        return sleep.filter { $0.stage.isAsleep && $0.end >= start && $0.end <= end && $0.end > $0.start }
    }

    static func hours(_ hours: Int, from date: Date, calendar: Calendar) -> Date {
        calendar.date(byAdding: .hour, value: hours, to: date) ?? date.addingTimeInterval(Double(hours) * 3600)
    }
}
