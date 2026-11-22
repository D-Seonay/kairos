import Foundation
import PulseDesignSystem
import PulseDomain
import PulseServices

/// Ce que VoiceOver lit de la page Profil, de Poids, de Paramètres et de Mes données : des phrases construites par des fonctions
/// pures, avec les nombres dits naturellement. Jamais « kg », « reps », « FC », « tiret », « point médian » ni un mois abrégé.
extension ProfileText {
    /// Dit quand une valeur ne peut pas se lire : jamais « tiret ».
    private static var unavailable: String { String(localized: "indisponible", bundle: .module) }

    // MARK: Poids

    /// « 80 kilos », « 2,5 kilos », « 1 kilo ».
    static func weightSpoken(_ kilograms: Double) -> String {
        guard kilograms.isFinite else { return unavailable }
        return PulseSpoken.kilos(kilograms)
    }

    /// « moins 0,8 kilo en 30 jours », « plus 1,3 kilo en 30 jours », « 0 kilo en 30 jours » : arrondi au dixième.
    static func weightChangeSpoken(_ kilograms: Double) -> String {
        guard kilograms.isFinite else { return unavailable }
        let rounded = (kilograms * 10).rounded() / 10
        let amount = PulseSpoken.kilos(abs(rounded))
        if rounded > 0 { return String(localized: "plus \(amount) en 30 jours", bundle: .module) }
        if rounded < 0 { return String(localized: "moins \(amount) en 30 jours", bundle: .module) }
        return String(localized: "\(amount) en 30 jours", bundle: .module)
    }

    /// « 78,4 kilos », ou « 78,4 kilos, dernière mesure le 3 novembre » quand la dernière pesée a plus de 14 jours.
    static func trendWeightSpoken(_ kilograms: Double, staleSince: Date?, calendar: Calendar, today: Date) -> String {
        let weight = weightSpoken(kilograms)
        guard let staleSince else { return weight }
        let day = spokenDate(staleSince, calendar: calendar, today: today)
        return String(localized: "\(weight), dernière mesure le \(day)", bundle: .module)
    }

    /// « 17,5 pour cent, le 12 novembre ».
    static func bodyFatSpoken(_ reading: BodyFatReading, calendar: Calendar, today: Date) -> String {
        guard reading.percent.isFinite else { return unavailable }
        let percent = PulseFormat.decimal(reading.percent, maxFractionDigits: 1)
        let day = spokenDate(reading.date, calendar: calendar, today: today)
        return String(localized: "\(percent) pour cent, le \(day)", bundle: .module)
    }

    /// « 28 octobre », ou « 28 octobre 2025 » hors de l'année de `today` : la date d'une pesée, d'un record ou d'un badge.
    static func spokenDate(_ date: Date, calendar: Calendar, today: Date) -> String {
        let day = PulseSpoken.date(date, calendar: calendar)
        let year = calendar.component(.year, from: date)
        guard year != calendar.component(.year, from: today) else { return day }
        // Une année n'est pas un nombre à grouper : « 2025 », pas « 2 025 ».
        let yearText = String(year)
        return String(localized: "\(day) \(yearText)", bundle: .module)
    }

    /// La tendance en une phrase : « 78,4 kilos, tendance sur 7 jours, moins 0,8 kilo en 30 jours » ; `nil` sans poids.
    static func weightTrendSpoken(_ trend: WeightTrend?, calendar: Calendar, today: Date) -> String? {
        guard let trend, let current = trend.current else { return nil }
        var parts = [weightSpoken(current), trendCaptionSpoken(trend, calendar: calendar, today: today)]
        if let change = trend.change30Days { parts.append(weightChangeSpoken(change)) }
        return parts.joined(separator: ", ")
    }

    /// « masse grasse 17,5 pour cent, le 12 novembre » ; `nil` sans mesure.
    static func bodyFatLineSpoken(_ trend: WeightTrend?, calendar: Calendar, today: Date) -> String? {
        guard let fat = trend?.latestBodyFat else { return nil }
        let reading = bodyFatSpoken(fat, calendar: calendar, today: today)
        return String(localized: "masse grasse \(reading)", bundle: .module)
    }

    /// La carte Poids de la page : titre, tendance, variation sur 30 jours et masse grasse en une phrase.
    static func weightCardSpoken(trend: WeightTrend?, calendar: Calendar, today: Date) -> String {
        var parts = [String(localized: "Poids et corps", bundle: .module)]
        if let trendText = weightTrendSpoken(trend, calendar: calendar, today: today) {
            parts.append(trendText)
        } else {
            parts.append(String(localized: "pas encore de pesée", bundle: .module))
            parts.append(String(localized: "ajoute une pesée ou autorise le poids dans Apple Santé", bundle: .module))
        }
        if let fat = bodyFatLineSpoken(trend, calendar: calendar, today: today) { parts.append(fat) }
        return parts.joined(separator: ", ")
    }

    /// « tendance sur 7 jours », ou « dernière mesure le 12 novembre » sans pesée depuis 14 jours.
    static func trendCaptionSpoken(_ trend: WeightTrend, calendar: Calendar, today: Date) -> String {
        if trend.isStale, let last = trend.lastMeasured {
            let day = spokenDate(last, calendar: calendar, today: today)
            return String(localized: "dernière mesure le \(day)", bundle: .module)
        }
        return String(localized: "tendance sur 7 jours", bundle: .module)
    }

    /// « 78,4 kilos, 17,5 pour cent de masse grasse, le 28 octobre, saisie manuelle » : une ligne de mesure.
    static func measurementSpoken(_ measurement: BodyMeasurement, calendar: Calendar, today: Date) -> String {
        var parts: [String] = []
        if let weight = measurement.weightKg { parts.append(weightSpoken(weight)) }
        if let fat = measurement.bodyFatPercent, fat.isFinite {
            let percent = PulseFormat.decimal(fat, maxFractionDigits: 1)
            parts.append(String(localized: "\(percent) pour cent de masse grasse", bundle: .module))
        }
        if parts.isEmpty { parts.append(unavailable) }
        let day = spokenDate(measurement.date, calendar: calendar, today: today)
        parts.append(String(localized: "le \(day)", bundle: .module))
        parts.append(sourceSpoken(measurement.source))
        return parts.joined(separator: ", ")
    }

    /// « Apple Santé » ou « saisie manuelle ».
    static func sourceSpoken(_ source: MeasurementSource) -> String {
        switch source {
        case .appleHealth: String(localized: "Apple Santé", bundle: .module)
        case .manual: String(localized: "saisie manuelle", bundle: .module)
        }
    }

    // MARK: Graphique du poids

    /// « Poids sur 90 jours, du 25 août au 20 novembre : tendance 78,4 kilos, de 77,6 à 80,3 kilos, 30 pesées. »
    static func weightChartSummary(weighed: [WeightDay], current: Double?, calendar: Calendar, today: Date) -> String {
        let dates = weighed.map(\.date)
        let weights = weighed.map(\.weightKg)
        let first = dates.min().map { spokenDate($0, calendar: calendar, today: today) } ?? ""
        let last = dates.max().map { spokenDate($0, calendar: calendar, today: today) } ?? ""
        let period = first == last
            ? String(localized: "le \(last)", bundle: .module)
            : String(localized: "du \(first) au \(last)", bundle: .module)
        let count = PulseSpoken.count(weighed.count, singular: String(localized: "pesée", bundle: .module),
                                      plural: String(localized: "pesées", bundle: .module))
        var parts: [String] = []
        if let current { parts.append(String(localized: "tendance \(weightSpoken(current))", bundle: .module)) }
        if weighed.count > 1 {
            let (lowest, highest) = (weights.min() ?? .nan, weights.max() ?? .nan)
            let high = weightSpoken(highest)
            if (lowest * 10).rounded() == (highest * 10).rounded() {
                parts.append(String(localized: "à \(high)", bundle: .module))
            } else {
                let low = PulseFormat.decimal(lowest, maxFractionDigits: 1)
                parts.append(String(localized: "de \(low) à \(high)", bundle: .module))
            }
        }
        parts.append(count)
        let body = parts.joined(separator: ", ")
        return String(localized: "Poids sur 90 jours, \(period) : \(body).", bundle: .module)
    }

    /// « 12 novembre » et « 78,4 kilos » : un point de pesée du graphique.
    static func weightPointSpoken(_ day: WeightDay, calendar: Calendar, today: Date) -> (label: String, value: String) {
        (spokenDate(day.date, calendar: calendar, today: today), weightSpoken(day.weightKg))
    }

    // MARK: Records et badges

    /// « 24 minutes 31 », « 1 heure 45 minutes 7 » : un temps de course.
    static func raceTimeSpoken(seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0, seconds < 1e12 else { return unavailable }
        return PulseSpoken.duration(seconds: Int(seconds.rounded()))
    }

    /// « 5 kilomètres », « 10 kilomètres », « Semi-marathon ».
    static func runTitleSpoken(_ distance: RunDistance) -> String {
        switch distance {
        case .fiveK: String(localized: "5 kilomètres", bundle: .module)
        case .tenK: String(localized: "10 kilomètres", bundle: .module)
        case .half: String(localized: "Semi-marathon", bundle: .module)
        }
    }

    /// « 120 kilos » pour un maximum estimé, « 14 répétitions » pour un record de répétitions.
    static func recordValueSpoken(_ line: StrengthRecordLine) -> String {
        switch line.kind {
        case .repsAtWeight:
            PulseSpoken.count(Int(line.value.rounded()), singular: String(localized: "répétition", bundle: .module),
                              plural: String(localized: "répétitions", bundle: .module))
        default: weightSpoken(line.value)
        }
    }

    /// « Squat : 120 kilos, le 28 octobre » : la valeur d'abord ; sans record, « Squat : pas encore de record ».
    static func liftRecordSpoken(title: String, line: StrengthRecordLine?, calendar: Calendar, today: Date) -> String {
        guard let line else { return String(localized: "\(title) : pas encore de record", bundle: .module) }
        let value = recordValueSpoken(line)
        let day = spokenDate(line.date, calendar: calendar, today: today)
        return String(localized: "\(title) : \(value), le \(day)", bundle: .module)
    }

    /// « 5 kilomètres : 24 minutes 31, le 14 septembre » ; sans temps, « 5 kilomètres : pas encore couru ».
    static func runRecordSpoken(_ run: RunBest, calendar: Calendar, today: Date) -> String {
        let title = runTitleSpoken(run.distance)
        guard let seconds = run.seconds else { return String(localized: "\(title) : pas encore couru", bundle: .module) }
        let time = raceTimeSpoken(seconds: seconds)
        guard let date = run.date else { return String(localized: "\(title) : \(time)", bundle: .module) }
        let day = spokenDate(date, calendar: calendar, today: today)
        return String(localized: "\(title) : \(time), le \(day)", bundle: .module)
    }

    /// « 4 semaines d'affilée, obtenu le 28 octobre » ; « 10 séances, pas encore obtenu, 37 sur 50 séances ».
    static func badgeAccessibility(_ badge: Badge, calendar: Calendar, today: Date) -> String {
        let title = badgeTitle(badge.kind)
        if let earnedAt = badge.earnedAt {
            let day = spokenDate(earnedAt, calendar: calendar, today: today)
            return String(localized: "\(title), obtenu le \(day)", bundle: .module)
        }
        let progress = badgeProgressSpoken(badge)
        return String(localized: "\(title), pas encore obtenu, \(progress)", bundle: .module)
    }

    /// « 9 sur 12 semaines », « 37 sur 50 séances ».
    static func badgeProgressSpoken(_ badge: Badge) -> String {
        let ratio = PulseSpoken.outOf(badge.current, badge.goal)
        switch badge.kind {
        case .streak, .firstFullMonth: return String(localized: "\(ratio) semaines", bundle: .module)
        case .sessions: return String(localized: "\(ratio) séances", bundle: .module)
        }
    }

    // MARK: Tuiles et en-tête

    /// « 58 sur 100, estimé ».
    static func morningScoreSpoken(_ score: Double, isEstimated: Bool) -> String {
        guard score.isFinite, abs(score) < 1e9 else { return unavailable }
        let text = PulseSpoken.outOf(Int(score.rounded()), 100)
        return isEstimated ? String(localized: "\(text), estimé", bundle: .module) : text
    }

    /// « 12 séances, depuis mars 2026 » ; « Aucune séance pour l'instant » sans séance.
    static func sessionsSinceSpoken(_ count: Int, firstSession: Date?, calendar: Calendar) -> String {
        guard count > 0, let firstSession else { return String(localized: "Aucune séance pour l'instant", bundle: .module) }
        let sessions = PulseSpoken.count(count, singular: String(localized: "séance", bundle: .module),
                                         plural: String(localized: "séances", bundle: .module))
        let month = firstSession.formatted(style(Date.FormatStyle.dateTime.month(.wide).year(), calendar: calendar))
        return String(localized: "\(sessions), depuis \(month)", bundle: .module)
    }

    /// « Profil, Mathéo, 12 séances, depuis mars 2026 » : l'en-tête de la page, titre d'écran compris.
    static func headerSpoken(name: String, sessions: String?) -> String {
        [String(localized: "Profil", bundle: .module), name, sessions].compactMap { $0 }.joined(separator: ", ")
    }

    /// « Score du matin, 58 sur 100, estimé » : une tuile en une phrase. Sans valeur, le titre et la phrase qui la remplace ; sans
    /// `spoken`, la valeur et son unité telles qu'affichées.
    static func tileSpoken(title: String, value: String?, unit: String?, spoken: String?, emptyText: String) -> String {
        guard let value else { return [title, emptyText].joined(separator: ", ") }
        let reading = spoken ?? ([value] + (unit.map { [$0] } ?? [])).joined(separator: " ")
        return [title, reading].joined(separator: ", ")
    }

    // MARK: Paramètres

    /// « Variabilité de la fréquence cardiaque », « Fréquence cardiaque au repos » : le nom d'un type lu, sans abréviation.
    static func healthKindSpoken(_ kind: HealthSampleKind) -> String {
        switch kind {
        case .sdnn: String(localized: "Variabilité de la fréquence cardiaque", bundle: .module)
        case .restingHeartRate: String(localized: "Fréquence cardiaque au repos", bundle: .module)
        default: healthKind(kind)
        }
    }

    /// « Sommeil, dernière donnée le 12 novembre » ; « Courses, aucune donnée lue ».
    static func healthRowSpoken(_ kind: HealthSampleKind, latest: Date?, calendar: Calendar, today: Date) -> String {
        let name = healthKindSpoken(kind)
        guard let latest else { return String(localized: "\(name), aucune donnée lue", bundle: .module) }
        let day = spokenDate(latest, calendar: calendar, today: today)
        return String(localized: "\(name), dernière donnée le \(day)", bundle: .module)
    }

    /// « Dernière donnée reçue : 12 novembre à 7 heures 30 » ; « … : jamais ».
    static func lastReadSpoken(_ date: Date?, calendar: Calendar, today: Date) -> String {
        guard let date else { return String(localized: "Dernière donnée reçue : jamais", bundle: .module) }
        let day = spokenDate(date, calendar: calendar, today: today)
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        let clock = PulseSpoken.clock(hour: parts.hour ?? 0, minute: parts.minute ?? 0)
        return String(localized: "Dernière donnée reçue : \(day) à \(clock)", bundle: .module)
    }

    /// « 90 secondes » : un repos par défaut.
    static func restSpoken(_ seconds: Int) -> String {
        PulseSpoken.count(seconds, singular: String(localized: "seconde", bundle: .module),
                          plural: String(localized: "secondes", bundle: .module))
    }

    /// « 20 kilos », « 2,5 kilos », « 1,25 kilo » : une barre ou un disque.
    static func plateSpoken(_ kilograms: Double) -> String {
        weightSpoken(kilograms)
    }

    /// « 7 heures 30 » : l'heure plafond du score du matin, en minutes après minuit.
    static func clockSpoken(minutes: Int) -> String {
        let clamped = min(max(0, minutes), 24 * 60 - 1)
        return PulseSpoken.clock(hour: clamped / 60, minute: clamped % 60)
    }

    static var birthDateHint: String {
        String(localized: "Sert à calculer la fréquence cardiaque maximale des courses", bundle: .module)
    }

    static var heightFieldLabel: String { String(localized: "Taille, en centimètres", bundle: .module) }
    static var weightFieldLabel: String { String(localized: "Poids, en kilos", bundle: .module) }

    // MARK: Annonces

    static var exportStarted: String { String(localized: "Export en cours", bundle: .module) }
    static var exportReady: String { String(localized: "Export prêt. Touche Partager l'export.", bundle: .module) }
    static var healthReadStarted: String { String(localized: "Lecture d'Apple Santé en cours", bundle: .module) }
    static var healthReadFinished: String { String(localized: "Lecture d'Apple Santé terminée", bundle: .module) }
}
