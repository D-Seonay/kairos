import Foundation
import PulseDesignSystem
import PulseDomain

/// Les textes et états que les widgets Série, Semaine, Prochaine séance et Charge tirent de l'instantané (spec M6 §11).
enum WidgetPlanningText {
    /// L'instantané du jour avec sa série et sa semaine.
    struct Planning {
        var snapshot: WidgetSnapshot
        var streak: WidgetStreak
        var week: [WidgetDay]
    }

    /// L'instantané de `date`, quand il porte la semaine et la série.
    static func planning(_ snapshot: WidgetSnapshot?, at date: Date, calendar: Calendar) -> Planning? {
        guard let snapshot, calendar.isDate(snapshot.day, inSameDayAs: date), let streak = snapshot.streak,
              let week = snapshot.week, week.count == 7 else { return nil }
        return Planning(snapshot: snapshot, streak: streak, week: week)
    }

    /// Un jour fait est plein, aujourd'hui marqué, un jour prévu creux. Un jour manqué se montre comme un repos : le widget
    /// ne fait pas de reproche.
    static func state(of day: WidgetDay) -> StreakWidgetContent.DayState {
        switch day.state {
        case .done: .completed
        case _ where day.isToday: .today
        case .planned: .upcoming
        case .missed, .rest: .rest
        }
    }

    /// « L », « M », « M », « J », « V », « S », « D ».
    static func letter(of day: WidgetDay, calendar: Calendar) -> String {
        let letters = ["L", "M", "M", "J", "V", "S", "D"]
        let index = (calendar.component(.weekday, from: day.date) + 5) % 7
        return letters[index]
    }

    static func icon(of kind: WidgetDayKind) -> String {
        switch kind {
        case .strength: "dumbbell.fill"
        case .run: "figure.run"
        case .rest: "minus"
        }
    }

    /// « 1,12 ».
    static func ratio(_ value: Double) -> String {
        PulseFormat.decimal(value, maxFractionDigits: 2)
    }

    /// La zone du ratio en toutes lettres, comme sur la carte de l'accueil.
    static func zone(of ratio: Double) -> (text: String, isOptimal: Bool) {
        if ratio < 0.8 { return (String(localized: "Sous-entraînement", bundle: .module), false) }
        if ratio <= 1.3 { return (String(localized: "Zone optimale", bundle: .module), true) }
        if ratio < 1.5 { return (String(localized: "Charge élevée", bundle: .module), false) }
        return (String(localized: "Risque de blessure", bundle: .module), false)
    }

    /// « Demain », « Jeudi ».
    static func timing(of date: Date, from now: Date, calendar: Calendar) -> String {
        let today = calendar.startOfDay(for: now)
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: today), calendar.isDate(date, inSameDayAs: tomorrow) {
            return String(localized: "Demain", bundle: .module)
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date).capitalized(with: Locale(identifier: "fr_FR"))
    }
}
