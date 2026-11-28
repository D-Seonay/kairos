import Foundation
import PulseContent
import PulseDesignSystem
import PulseDomain
import PulseServices

/// Les textes de l'onglet Planning, tirés de la semaine datée (spec M6 §7).
enum PlanningText {
    /// « 11 240 kg », sans décimale.
    static func tonnage(_ kilograms: Double) -> String {
        PulseUnits.current.weight(kilograms, maxFractionDigits: 0, grouped: true)
    }

    /// « 8,2 km ».
    static func distance(meters: Double) -> String {
        let units = PulseUnits.current
        let distance = units.displayedDistance(meters: meters)
            .formatted(.number.precision(.fractionLength(1)).locale(Locale(identifier: "fr_FR")))
        return "\(distance) \(units.distanceSymbol)"
    }

    /// « 5:29 /km » ; `nil` sans distance ou sans durée.
    static func pace(minutes: Double?, meters: Double?) -> String? {
        let units = PulseUnits.current
        return secondsPerKilometer(minutes: minutes, meters: meters).map {
            let seconds = units.paceSeconds(secondsPerKilometer: Double($0))
            return String(format: "%d:%02d \(units.paceSuffix)", seconds / 60, seconds % 60)
        }
    }

    /// « 5 minutes 29 par kilomètre » ; `nil` sans distance ou sans durée.
    static func paceSpoken(minutes: Double?, meters: Double?) -> String? {
        secondsPerKilometer(minutes: minutes, meters: meters).map { PulseSpoken.pace(secondsPerKilometer: $0) }
    }

    private static func secondsPerKilometer(minutes: Double?, meters: Double?) -> Int? {
        guard let minutes, let meters, minutes > 0, meters > 0 else { return nil }
        return Int((minutes * 60 / (meters / 1000)).rounded())
    }

    /// « 8,2 kilomètres », « 1 kilomètre ».
    static func distanceSpoken(meters: Double) -> String {
        PulseSpoken.kilometres(meters / 1000)
    }

    /// « Série de 3 semaines · 2 sur 5 cette semaine » ; dit « Série de 3 semaines, 2 sur 5 cette semaine » : le point médian
    /// n'est pas lu.
    static func streakRow(weeks: Int, count: Int, target: Int, spoken: Bool = false) -> String {
        let streak = String(localized: "Série de \(weeksText(weeks))", bundle: .module)
        let progress = String(localized: "\(count) sur \(target) cette semaine", bundle: .module)
        return spoken
            ? String(localized: "\(streak), \(progress)", bundle: .module)
            : String(localized: "\(streak) · \(progress)", bundle: .module)
    }

    /// « Mois et série, Série de 3 semaines, 2 sur 5 cette semaine » : la rangée qui ouvre le mois, d'un seul tenant.
    static func monthEntrySpoken(weeks: Int, count: Int, target: Int) -> String {
        let title = String(localized: "Mois et série", bundle: .module)
        return String(localized: "\(title), \(streakRow(weeks: weeks, count: count, target: target, spoken: true))", bundle: .module)
    }

    /// « 1 semaine réussie sur les 8 dernières », « 5 semaines réussies sur les 8 dernières ».
    static func pillarText(successes: Int, total: Int) -> String {
        let done = PulseSpoken.count(successes, singular: String(localized: "semaine réussie", bundle: .module),
                                     plural: String(localized: "semaines réussies", bundle: .module))
        return String(localized: "\(done) sur les \(total) dernières", bundle: .module)
    }

    /// « semaine d'affilée », « semaines d'affilée » : le mot sous le compteur de la série.
    static func weeksInARow(_ weeks: Int) -> String {
        weeks <= 1 ? String(localized: "semaine d'affilée", bundle: .module) : String(localized: "semaines d'affilée", bundle: .module)
    }

    private static func weeksText(_ weeks: Int) -> String {
        PulseSpoken.count(weeks, singular: String(localized: "semaine", bundle: .module),
                          plural: String(localized: "semaines", bundle: .module))
    }

    /// « 150 battements par minute ».
    static func heartRateSpoken(_ beatsPerMinute: Int) -> String {
        String(localized: "\(beatsPerMinute) battements par minute", bundle: .module)
    }

    /// « Aujourd'hui · mercredi 18 » ; dit « Aujourd'hui, mercredi 18 » : le point médian n'est pas lu.
    static func todayHeading(weekday: String, number: String, spoken: Bool = false) -> String {
        spoken
            ? String(localized: "Aujourd'hui, \(weekday) \(number)", bundle: .module)
            : String(localized: "Aujourd'hui · \(weekday) \(number)", bundle: .module)
    }

    /// « lundi 16, aujourd'hui, Pectoraux, Prévue » : la bande et la liste lisent un jour de la même façon. Le détail est
    /// celui de `PlanningModel.spokenDetail(of:)`, sans abréviation.
    static func dayAccessibility(weekday: String, number: String, isToday: Bool, title: String, detail: String) -> String {
        var parts = ["\(weekday) \(number)"]
        if isToday { parts.append(String(localized: "aujourd'hui", bundle: .module)) }
        parts.append(title)
        parts.append(detail)
        return parts.joined(separator: ", ")
    }

    /// Ce qu'une séance faite a donné : tonnage d'une séance de musculation, distance ou durée d'une course ou d'un vélo.
    /// `spoken` écrit les unités en toutes lettres (« 11 240 kilos », « 8,2 kilomètres », « 45 minutes »).
    static func result(of session: WorkoutSession, spoken: Bool = false) -> String {
        switch session.kind {
        case .strength:
            if session.tonnageKg > 0 { return spoken ? PulseSpoken.kilos(session.tonnageKg) : tonnage(session.tonnageKg) }
            let sets = session.sets.filter { $0.setType != .warmup }.count
            return PulseSpoken.count(sets, singular: String(localized: "série", bundle: .module),
                                     plural: String(localized: "séries", bundle: .module))
        case .run, .ride:
            if let meters = session.distanceMeters, meters > 0 { return spoken ? distanceSpoken(meters: meters) : distance(meters: meters) }
            let minutes = Int((session.durationMinutes ?? 0).rounded())
            return spoken ? PulseSpoken.duration(seconds: minutes * 60) : PulseFormat.duration(minutes: minutes)
        }
    }

    /// « Sortie facile · 45 min », « Fractionné · 8 km », « Course » ; dit « Sortie facile, 45 minutes ».
    static func run(_ day: RoutineDay, spoken: Bool = false) -> String {
        var parts = [day.runType?.localizedName ?? String(localized: "Course", bundle: .module)]
        if let minutes = day.runTargetMinutes {
            parts.append(spoken
                ? PulseSpoken.duration(seconds: minutes * 60)
                : String(localized: "\(minutes) min", bundle: .module))
        } else if let km = day.runTargetKm {
            parts.append(spoken
                ? PulseSpoken.kilometres(km)
                : PulseUnits.current.distance(kilometres: km, maxFractionDigits: 1, grouped: true))
        }
        return parts.joined(separator: spoken ? ", " : " · ")
    }

    /// L'icône d'une discipline.
    static func icon(of kind: SessionKind) -> String {
        switch kind {
        case .strength: "dumbbell.fill"
        case .run: "figure.run"
        case .ride: "figure.outdoor.cycle"
        }
    }

    static func icon(of kind: RoutineDayKind) -> String {
        switch kind {
        case .strength: "dumbbell.fill"
        case .run: "figure.run"
        }
    }
}
