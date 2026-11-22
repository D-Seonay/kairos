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

    // MARK: - Textes lus par VoiceOver

    /// « Lundi fait, mardi repos, aujourd'hui mercredi, jeudi à venir » : l'état des 7 pastilles, jour par jour. Vide quand les
    /// jours et les dates ne se correspondent pas.
    static func spokenWeek(days: [StreakWidgetContent.DayState], dates: [Date], calendar: Calendar) -> String {
        guard days.count == dates.count, !days.isEmpty else { return "" }
        let parts = zip(days, dates).map { state, date -> String in
            let name = PulseSpoken.weekday(date, calendar: calendar)
            return switch state {
            case .completed: String(localized: "\(name) fait", bundle: .module)
            case .rest: String(localized: "\(name) repos", bundle: .module)
            case .today: String(localized: "aujourd'hui \(name)", bundle: .module)
            case .upcoming: String(localized: "\(name) à venir", bundle: .module)
            }
        }
        let sentence = parts.joined(separator: ", ")
        return sentence.prefix(1).uppercased() + sentence.dropFirst()
    }

    /// Les 7 jours de la semaine (du lundi au dimanche) de `date`, pour l'exemple sans instantané.
    static func weekDates(containing date: Date, calendar: Calendar) -> [Date] {
        let start = calendar.startOfDay(for: date)
        let offset = (calendar.component(.weekday, from: start) + 5) % 7
        guard let monday = calendar.date(byAdding: .day, value: -offset, to: start) else { return [] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: monday) }
    }

    /// « 5 minutes 45 à 6 minutes 5 par kilomètre » : la fourchette d'allure, en secondes par kilomètre.
    static func spokenPace(fastest: Int, slowest: Int) -> String {
        let from = PulseSpoken.duration(seconds: fastest)
        let to = PulseSpoken.duration(seconds: slowest)
        return String(localized: "\(from) à \(to) par kilomètre", bundle: .module)
    }

    /// Le détail d'une séance dit en toutes lettres : « Sortie facile · 45 min » donne « Sortie facile, 45 minutes », et
    /// « 12,5 km » donne « 12,5 kilomètres ».
    static func spokenDetail(_ detail: String) -> String {
        var spoken = detail.replacing(" · ", with: ", ")
        spoken = spoken.replacing(/(\d+) min\b/) { match in
            PulseSpoken.duration(seconds: (Int(match.1) ?? 0) * 60)
        }
        spoken = spoken.replacing(/(\d+(?:[.,]\d+)?) km\b/) { match in
            let number = String(match.1)
            let value = Double(number.replacing(",", with: ".")) ?? 0
            return value <= 1
                ? String(localized: "\(number) kilomètre", bundle: .module)
                : String(localized: "\(number) kilomètres", bundle: .module)
        }
        return spoken
    }
}
