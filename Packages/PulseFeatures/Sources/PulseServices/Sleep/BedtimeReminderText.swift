import Foundation

/// Les textes du rappel de coucher : le titre donne le coucher conseillé, le corps la raison du soir.
public enum BedtimeReminderText {
    /// « Au lit avant 22:45 ».
    public static func title(bedtime: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.hour, .minute], from: bedtime)
        let clock = SleepPlan.clockText(minutes: (parts.hour ?? 0) * 60 + (parts.minute ?? 0))
        return String(localized: "Au lit avant \(clock)", bundle: .module)
    }

    /// La nuit courte d'hier et la séance de demain d'abord ; sans l'une ni l'autre, l'heure du réveil visé.
    public static func body(goalMinutes: Int, wakeMinutes: Int, shortNightMinutes: Int?, sessionName: String?) -> String {
        let goal = duration(minutes: goalMinutes)
        switch (shortNightMinutes.map(duration(minutes:)), sessionName) {
        case let (short?, session?):
            return String(localized: "Nuit courte hier (\(short)) et séance \(session) demain : vise tes \(goal).", bundle: .module)
        case let (short?, nil):
            return String(localized: "Nuit courte hier (\(short)) : vise tes \(goal) cette nuit.", bundle: .module)
        case let (nil, session?):
            return String(localized: "Séance \(session) demain : vise tes \(goal) de sommeil.", bundle: .module)
        case (nil, nil):
            let wake = SleepPlan.clockText(minutes: wakeMinutes)
            return String(localized: "Pour tes \(goal) de sommeil avant le réveil de \(wake).", bundle: .module)
        }
    }

    /// « 8 h », « 6 h 10 », « 7 h 05 », « 45 min », comme `PulseFormat.duration` (que PulseServices ne voit pas).
    public static func duration(minutes: Int) -> String {
        let hours = minutes / 60
        let rest = minutes % 60
        if hours == 0 {
            return String(localized: "\(rest) min", bundle: .module)
        }
        if rest == 0 {
            return String(localized: "\(hours) h", bundle: .module)
        }
        let padded = rest < 10 ? "0\(rest)" : "\(rest)"
        return String(localized: "\(hours) h \(padded)", bundle: .module)
    }
}
