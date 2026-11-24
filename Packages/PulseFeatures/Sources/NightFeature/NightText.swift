import Foundation
import PulseDesignSystem
import PulseDomain
import PulseServices

/// Une ligne de la répartition : la phase, ses minutes, sa part de la nuit (0…1) et l'écart à la moyenne (« +12 min »).
struct BreakdownRow: Equatable, Identifiable {
    var stage: SleepStage
    var minutes: Int
    var share: Double
    var delta: String?

    var id: SleepStage { stage }
}

/// Les textes de l'écran Nuit, affichés et parlés. Vocabulaire neutre : l'écran montre, il ne diagnostique pas.
enum NightText {
    // MARK: - Affichés

    /// « Nuit du 19 au 20 nov. », « Nuit du 31 oct. au 1 nov. » : du soir au jour de réveil.
    static func title(_ night: NightSleep, calendar: Calendar) -> String {
        let evening = calendar.date(byAdding: .day, value: -1, to: night.day) ?? night.day
        let sameMonth = calendar.component(.month, from: evening) == calendar.component(.month, from: night.day)
        let start = formatted(evening, calendar: calendar, format: sameMonth ? "d" : "d MMM")
        let end = formatted(night.day, calendar: calendar, format: "d MMM")
        return String(localized: "Nuit du \(start) au \(end)", bundle: .module)
    }

    /// « Endormi à 23:10 · Réveillé à 06:50 · 1 réveil ».
    static func times(_ night: NightSleep, calendar: Calendar) -> String {
        let asleep = formatted(night.fellAsleep, calendar: calendar, format: "HH:mm")
        let awake = formatted(night.wokeUp, calendar: calendar, format: "HH:mm")
        return String(localized: "Endormi à \(asleep) · Réveillé à \(awake) · \(awakenings(night.awakenings))", bundle: .module)
    }

    /// « aucun réveil », « 1 réveil », « 3 réveils ».
    static func awakenings(_ count: Int) -> String {
        switch count {
        case 0: String(localized: "aucun réveil", bundle: .module)
        case 1: String(localized: "1 réveil", bundle: .module)
        default: String(localized: "\(count) réveils", bundle: .module)
        }
    }

    /// « 20 % ».
    static func share(_ share: Double) -> String {
        PulseFormat.integer(share * 100, unit: "%")
    }

    /// « +12 min », « −5 min » ; rien sans moyenne ou quand l'écart arrondi est nul.
    static func delta(minutes: Int, average: Double?) -> String? {
        guard let average, average.isFinite else { return nil }
        let difference = Double(minutes) - average
        guard Int(difference.rounded()) != 0 else { return nil }
        return PulseFormat.signedInteger(difference, unit: "min")
    }

    /// « Aussi compté : 18:05–18:30, 25 min ».
    static func otherBlock(_ block: SleepBlock, calendar: Calendar) -> String {
        let start = formatted(block.start, calendar: calendar, format: "HH:mm")
        let end = formatted(block.end, calendar: calendar, format: "HH:mm")
        let duration = PulseFormat.duration(minutes: block.asleepMinutes)
        return String(localized: "Aussi compté : \(start)–\(end), \(duration)", bundle: .module)
    }

    static var noStagesNote: String {
        // swiftlint:disable:next line_length
        String(localized: "Ta source n'envoie pas les phases de sommeil à Apple Santé : seuls l'endormissement, le réveil et la durée sont connus.",
               bundle: .module)
    }

    static var emptyNote: String {
        String(localized: "Aucune nuit enregistrée ces 60 derniers jours.", bundle: .module)
    }

    /// Profond, léger, paradoxal, éveil, puis endormi sans phase s'il y en a. La part se calcule sur la somme des lignes ;
    /// vide quand la source ne donne pas de phases.
    static func breakdownRows(_ detail: NightDetail) -> [BreakdownRow] {
        let night = detail.night
        guard night.hasStages else { return [] }
        let averages = detail.averages
        var rows = [BreakdownRow(stage: .deep, minutes: night.deepMinutes, share: 0,
                                 delta: delta(minutes: night.deepMinutes, average: averages?.deep)),
                    BreakdownRow(stage: .core, minutes: night.coreMinutes, share: 0,
                                 delta: delta(minutes: night.coreMinutes, average: averages?.core)),
                    BreakdownRow(stage: .rem, minutes: night.remMinutes, share: 0,
                                 delta: delta(minutes: night.remMinutes, average: averages?.rem)),
                    BreakdownRow(stage: .awake, minutes: night.awakeMinutes, share: 0,
                                 delta: delta(minutes: night.awakeMinutes, average: averages?.awake))]
        if night.unspecifiedMinutes > 0 {
            rows.append(BreakdownRow(stage: .asleepUnspecified, minutes: night.unspecifiedMinutes, share: 0, delta: nil))
        }
        let total = Double(rows.reduce(0) { $0 + $1.minutes })
        return rows.map { row in
            var shared = row
            shared.share = total > 0 ? Double(row.minutes) / total : 0
            return shared
        }
    }

    // MARK: - Parlés

    /// « Endormi à 23 heures 10, réveillé à 6 heures 50, 1 réveil, 7 heures 30 minutes de sommeil, dont 1 heure 30 minutes de
    /// profond, 5 heures de léger, 1 heure de paradoxal ».
    static func spokenSummary(_ night: NightSleep, calendar: Calendar) -> String {
        let asleep = spokenClock(night.fellAsleep, calendar: calendar)
        let awake = spokenClock(night.wokeUp, calendar: calendar)
        let total = spokenMinutes(night.asleepMinutes)
        var text = String(localized: "Endormi à \(asleep), réveillé à \(awake), \(awakenings(night.awakenings)), \(total) de sommeil",
                          bundle: .module)
        guard night.hasStages else {
            return text + String(localized: ", phases non fournies par ta source", bundle: .module)
        }
        let stages = [(SleepStage.deep, night.deepMinutes), (.core, night.coreMinutes), (.rem, night.remMinutes),
                      (.asleepUnspecified, night.unspecifiedMinutes)]
            .filter { $0.1 > 0 }
            .map { stage, minutes in "\(spokenMinutes(minutes)) \(spokenStage(stage))" }
        if !stages.isEmpty {
            text += String(localized: ", dont \(stages.joined(separator: ", "))", bundle: .module)
        }
        return text
    }

    /// « La nuit du 19 au 20 novembre », pour les boutons ‹ ›.
    static func spokenTitle(_ night: NightSleep, calendar: Calendar) -> String {
        let evening = calendar.date(byAdding: .day, value: -1, to: night.day) ?? night.day
        let sameMonth = calendar.component(.month, from: evening) == calendar.component(.month, from: night.day)
        let start = sameMonth ? formatted(evening, calendar: calendar, format: "d") : PulseSpoken.date(evening, calendar: calendar)
        return String(localized: "La nuit du \(start) au \(PulseSpoken.date(night.day, calendar: calendar))", bundle: .module)
    }

    /// « de profond », « de léger », « de paradoxal », « sans phase ».
    private static func spokenStage(_ stage: SleepStage) -> String {
        switch stage {
        case .deep: String(localized: "de profond", bundle: .module)
        case .core: String(localized: "de léger", bundle: .module)
        case .rem: String(localized: "de paradoxal", bundle: .module)
        case .awake: String(localized: "d'éveil", bundle: .module)
        case .asleepUnspecified, .inBed: String(localized: "sans phase", bundle: .module)
        }
    }

    static func spokenMinutes(_ minutes: Int) -> String {
        PulseSpoken.duration(seconds: minutes * 60)
    }

    private static func spokenClock(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return PulseSpoken.clock(hour: parts.hour ?? 0, minute: parts.minute ?? 0)
    }

    private static func formatted(_ date: Date, calendar: Calendar, format: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = format
        return formatter.string(from: date)
    }
}
