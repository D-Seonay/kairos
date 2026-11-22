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

    /// « Lundi fait, mardi repos, aujourd'hui mercredi, à venir, jeudi à venir » : l'état des 7 pastilles, jour par jour. Aujourd'hui
    /// se dit toujours « aujourd'hui », quel que soit son état. Un jour manqué se dit « repos », comme il se voit : pas de reproche.
    static func spokenWeek(_ week: [WidgetDay], calendar: Calendar) -> String {
        let parts = week.map { day -> String in
            let name = PulseSpoken.weekday(day.date, calendar: calendar)
            let status = switch day.state {
            case .done: String(localized: "fait", bundle: .module)
            case .planned: String(localized: "à venir", bundle: .module)
            case .missed, .rest: String(localized: "repos", bundle: .module)
            }
            return day.isToday ? String(localized: "aujourd'hui \(name), \(status)", bundle: .module)
                : String(localized: "\(name) \(status)", bundle: .module)
        }
        let sentence = parts.joined(separator: ", ")
        return sentence.prefix(1).uppercased() + sentence.dropFirst()
    }

    /// La semaine de l'exemple : trois jours faits, un repos, aujourd'hui vendredi prévu, une course samedi, un repos dimanche.
    static func sampleWeek(containing date: Date, calendar: Calendar) -> [WidgetDay] {
        let layout: [(WidgetDayKind, WidgetDayState)] = [(.strength, .done), (.run, .done), (.strength, .done), (.rest, .rest),
                                                         (.strength, .planned), (.run, .planned), (.rest, .rest)]
        return zip(weekDates(containing: date, calendar: calendar), layout).enumerated().map { index, entry in
            WidgetDay(date: entry.0, kind: entry.1.0, state: entry.1.1, isToday: index == 4)
        }
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
            PulseSpoken.kilometres(Double(match.1.replacing(",", with: ".")) ?? 0)
        }
        return spoken
    }
}
