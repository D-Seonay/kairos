import Foundation
import PulseDesignSystem
import PulseDomain
import PulseServices

/// Les formats français de la page Profil : `PulseFormat` pour les nombres, les dates et les temps de course comme dans Stats
/// (`StatsText` est interne à son module).
enum ProfileText {
    /// Une valeur impossible à afficher (non finie) donne « — », comme `PulseFormat`.
    private static let dash = "\u{2014}"
    private static let minus = "\u{2212}"
    private static let french = Locale(identifier: "fr_FR")

    /// « 12 séances · depuis mars 2026 », « 1 séance · depuis mars 2026 » ; « Aucune séance pour l'instant » sans séance.
    static func sessionsSince(_ count: Int, firstSession: Date?, calendar: Calendar) -> String {
        guard count > 0, let firstSession else { return String(localized: "Aucune séance pour l'instant", bundle: .module) }
        let sessions = count == 1
            ? String(localized: "1 séance", bundle: .module)
            : String(localized: "\(count) séances", bundle: .module)
        let month = firstSession.formatted(style(Date.FormatStyle.dateTime.month(.wide).year(), calendar: calendar))
        return String(localized: "\(sessions) · depuis \(month)", bundle: .module)
    }

    /// « 1 semaine », « 3 semaines » (et « 0 semaine »).
    static func weeks(_ weeks: Int) -> String {
        weeks < 2
            ? String(localized: "\(weeks) semaine", bundle: .module)
            : String(localized: "\(weeks) semaines", bundle: .module)
    }

    /// « semaine » jusqu'à 1, « semaines » au-delà : l'unité sous le chiffre de la série.
    static func weeksUnit(_ weeks: Int) -> String {
        weeks < 2 ? String(localized: "semaine", bundle: .module) : String(localized: "semaines", bundle: .module)
    }

    /// La ligne sous les exports de Mes données : les photos de séance y sont, les photos de corps jamais.
    static var photosExportNote: String {
        String(localized:
            "Les photos de séance sont dans l'export CSV. Les photos de corps n'y sont jamais : exporte-les depuis leur écran.",
            bundle: .module)
    }

    /// « 78,4 kg ».
    static func weight(_ kilograms: Double) -> String {
        guard kilograms.isFinite else { return dash }
        return String(localized: "\(PulseFormat.decimal(kilograms, maxFractionDigits: 1)) kg", bundle: .module)
    }

    /// « −0,8 kg en 30 j », « +1,3 kg en 30 j », « 0 kg en 30 j » : arrondi au dixième, signe moins U+2212.
    static func weightChange(_ kilograms: Double) -> String {
        guard kilograms.isFinite else { return dash }
        let rounded = (kilograms * 10).rounded() / 10
        let magnitude = PulseFormat.decimal(abs(rounded), maxFractionDigits: 1)
        let signed = rounded > 0 ? "+\(magnitude)" : rounded < 0 ? "\(minus)\(magnitude)" : magnitude
        return String(localized: "\(signed) kg en 30 j", bundle: .module)
    }

    /// « 17,5 % · 12 nov. ».
    static func bodyFat(_ reading: BodyFatReading, calendar: Calendar, today: Date) -> String {
        guard reading.percent.isFinite else { return dash }
        let percent = "\(PulseFormat.decimal(reading.percent, maxFractionDigits: 1)) %"
        return [percent, shortDate(reading.date, calendar: calendar, today: today)].joined(separator: " · ")
    }

    /// « tendance sur 7 jours », ou « dernière mesure le 12 nov. » sans pesée depuis 14 jours (spec M7 §14).
    static func trendCaption(_ trend: WeightTrend, calendar: Calendar, today: Date) -> String {
        if trend.isStale, let last = trend.lastMeasured {
            let day = shortDate(last, calendar: calendar, today: today)
            return String(localized: "dernière mesure le \(day)", bundle: .module)
        }
        return String(localized: "tendance sur 7 jours", bundle: .module)
    }

    /// « 78,4 kg », « 17,5 % de masse grasse », ou les deux séparés d'un point médian : la valeur d'une ligne de mesure.
    static func measurement(_ measurement: BodyMeasurement) -> String {
        var parts: [String] = []
        if let weight = measurement.weightKg { parts.append(self.weight(weight)) }
        if let fat = measurement.bodyFatPercent, fat.isFinite {
            parts.append(String(localized: "\(PulseFormat.decimal(fat, maxFractionDigits: 1)) % de masse grasse",
                                bundle: .module))
        }
        return parts.isEmpty ? dash : parts.joined(separator: " · ")
    }

    /// « Apple Santé » ou « Saisie ».
    static func source(_ source: MeasurementSource) -> String {
        switch source {
        case .appleHealth: String(localized: "Apple Santé", bundle: .module)
        case .manual: String(localized: "Saisie", bundle: .module)
        }
    }

    /// « 28 oct. », ou « 28 oct. 2025 » hors de l'année de `today` : la date d'une pesée ou d'un record.
    static func shortDate(_ date: Date, calendar: Calendar, today: Date) -> String {
        guard calendar.component(.year, from: date) != calendar.component(.year, from: today) else {
            return date.formatted(style(Date.FormatStyle.dateTime.day().month(.abbreviated), calendar: calendar))
        }
        return fullDate(date, calendar: calendar)
    }

    /// « 12 nov. 2026 ».
    static func fullDate(_ date: Date, calendar: Calendar) -> String {
        date.formatted(style(Date.FormatStyle.dateTime.day().month(.abbreviated).year(), calendar: calendar))
    }

    /// « 24:31 », « 1:45:07 » : un temps de course.
    static func raceTime(seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0, seconds < 1e12 else { return dash }
        let total = Int(seconds.rounded())
        let hours = total / 3_600
        let minutes = total % 3_600 / 60
        let rest = total % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, rest)
            : String(format: "%d:%02d", minutes, rest)
    }

    static func runTitle(_ distance: RunDistance) -> String {
        switch distance {
        case .fiveK: String(localized: "5 km", bundle: .module)
        case .tenK: String(localized: "10 km", bundle: .module)
        case .half: String(localized: "Semi-marathon", bundle: .module)
        }
    }

    /// Le nom d'un levé de base (`RecordStats.mainLifts`) qui n'a pas encore de record, donc pas de ligne nommée par le répertoire.
    static func mainLiftName(_ id: String) -> String {
        switch id {
        case "back-squat-barbell": String(localized: "Squat", bundle: .module)
        case "bench-press-barbell": String(localized: "Développé couché", bundle: .module)
        case "deadlift-barbell": String(localized: "Soulevé de terre", bundle: .module)
        case "overhead-press-barbell": String(localized: "Développé militaire", bundle: .module)
        default: id
        }
    }

    /// « 120 kg » pour un 1RM estimé, « 14 reps » pour un record de répétitions.
    static func recordValue(_ line: StrengthRecordLine) -> String {
        switch line.kind {
        case .repsAtWeight: String(localized: "\(Int(line.value.rounded())) reps", bundle: .module)
        default: weight(line.value)
        }
    }

    /// « 4 semaines d'affilée », « 10 séances », « Premier mois complet ».
    static func badgeTitle(_ kind: BadgeKind) -> String {
        switch kind {
        case let .streak(weeks): String(localized: "\(weeks) semaines d'affilée", bundle: .module)
        case let .sessions(count): String(localized: "\(count) séances", bundle: .module)
        case .firstFullMonth: String(localized: "Premier mois complet", bundle: .module)
        }
    }

    /// « 9 / 12 semaines », « 37 / 50 séances » ; le premier mois compte les semaines réussies de son meilleur mois.
    static func badgeProgress(_ badge: Badge) -> String {
        switch badge.kind {
        case .streak, .firstFullMonth: String(localized: "\(badge.current) / \(badge.goal) semaines", bundle: .module)
        case .sessions: String(localized: "\(badge.current) / \(badge.goal) séances", bundle: .module)
        }
    }

    // MARK: Paramètres

    /// Le nom d'un type lu dans Apple Santé.
    static func healthKind(_ kind: HealthSampleKind) -> String {
        switch kind {
        case .sdnn: String(localized: "VFC", bundle: .module)
        case .restingHeartRate: String(localized: "FC au repos", bundle: .module)
        case .heartRate: String(localized: "Fréquence cardiaque", bundle: .module)
        case .sleep: String(localized: "Sommeil", bundle: .module)
        case .run: String(localized: "Courses", bundle: .module)
        case .ride: String(localized: "Vélo", bundle: .module)
        case .bodyMass: String(localized: "Poids", bundle: .module)
        case .bodyFat: String(localized: "Masse grasse", bundle: .module)
        case .otherWorkout: String(localized: "Autres entraînements", bundle: .module)
        }
    }

    /// « 8 h », « 7 h 30 » : un objectif de sommeil.
    static func sleepGoal(minutes: Int) -> String {
        PulseFormat.duration(minutes: minutes)
    }

    /// « Selon mes nuits (07:00) » avec le réveil habituel mesuré, « Selon mes nuits » sans lui. L'heure est affichée, jamais
    /// écrite.
    static func followsNights(habitual: Int?) -> String {
        guard let habitual else { return String(localized: "Selon mes nuits", bundle: .module) }
        return String(localized: "Selon mes nuits (\(SleepPlan.clockText(minutes: habitual)))", bundle: .module)
    }

    /// « Coucher conseillé : 22:45 en semaine, 00:45 le week-end. », avec le seul jour connu, ou l'invitation à choisir un réveil.
    static func advisedBedtime(weekday: Int?, weekend: Int?) -> String {
        switch (weekday.map(SleepPlan.clockText), weekend.map(SleepPlan.clockText)) {
        case let (weekday?, weekend?):
            String(localized: "Coucher conseillé : \(weekday) en semaine, \(weekend) le week-end.", bundle: .module)
        case let (weekday?, nil): String(localized: "Coucher conseillé : \(weekday) en semaine.", bundle: .module)
        case let (nil, weekend?): String(localized: "Coucher conseillé : \(weekend) le week-end.", bundle: .module)
        case (nil, nil): String(localized: "Choisis une heure de réveil pour obtenir un coucher conseillé.", bundle: .module)
        }
    }

    /// « 30 min avant », « 1 h avant » : l'avance du rappel de coucher.
    static func bedtimeLead(minutes: Int) -> String {
        String(localized: "\(PulseFormat.duration(minutes: minutes)) avant", bundle: .module)
    }

    static func sex(_ sex: Sex) -> String {
        switch sex {
        case .female: String(localized: "Femme", bundle: .module)
        case .male: String(localized: "Homme", bundle: .module)
        case .unspecified: String(localized: "Non précisé", bundle: .module)
        }
    }

    /// « 12 nov. 2026 à 07:30 » : la dernière lecture d'Apple Santé.
    static func dateTime(_ date: Date, calendar: Calendar) -> String {
        date.formatted(style(Date.FormatStyle.dateTime.day().month(.abbreviated).year().hour().minute(), calendar: calendar))
    }

    /// Le format en français, dans le calendrier et le fuseau donnés.
    static func style(_ base: Date.FormatStyle, calendar: Calendar) -> Date.FormatStyle {
        var style = base
        style.locale = french
        style.calendar = calendar
        style.timeZone = calendar.timeZone
        return style
    }
}
