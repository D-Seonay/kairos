import Foundation
import PulseDesignSystem
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

    /// « 28 oct. », ou « 28 oct. 2025 » hors de l'année de `today` : la date d'une pesée ou d'un record.
    static func shortDate(_ date: Date, calendar: Calendar, today: Date) -> String {
        guard calendar.component(.year, from: date) != calendar.component(.year, from: today) else {
            return date.formatted(style(Date.FormatStyle.dateTime.day().month(.abbreviated), calendar: calendar))
        }
        return earnedDate(date, calendar: calendar)
    }

    /// « 12 nov. 2026 » : la date d'un badge obtenu, toujours avec l'année.
    static func earnedDate(_ date: Date, calendar: Calendar) -> String {
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

    /// Le format en français, dans le calendrier et le fuseau donnés.
    private static func style(_ base: Date.FormatStyle, calendar: Calendar) -> Date.FormatStyle {
        var style = base
        style.locale = french
        style.calendar = calendar
        style.timeZone = calendar.timeZone
        return style
    }
}
