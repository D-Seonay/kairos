import Foundation
import PulseDesignSystem
import PulseDomain
import PulseServices

/// La lecture de la nuit en français : ce que chaque facteur a dit, ce qui manque, la ligne de base, puis la conclusion de la catégorie,
/// accordée à la séance du jour.
enum WhyReading {
    /// Sous ce sommeil, la phrase dit « tu n'as dormi que ».
    private static let shortSleepMinutes = 420
    /// À partir de cet écart arrondi, la VFC est dite au-dessus ou sous sa moyenne.
    private static let hrvThresholdPercent = 5
    /// À partir de cet écart arrondi, la FC au repos est dite en hausse ou en baisse.
    private static let heartRateThresholdBpm = 2

    static func make(recovery: DailyRecovery, session: TodaySession) -> String {
        var sentences: [String]
        if recovery.isEstimated {
            sentences = [String(localized: "Pas de données de nuit : ce score vient de ton check-in.", bundle: .module)]
        } else {
            sentences = measured(recovery)
        }
        sentences.append(contentsOf: conclusion(recovery.category, session: session))
        return sentences.joined(separator: " ")
    }

    // MARK: - Nuit mesurée

    private static func measured(_ recovery: DailyRecovery) -> [String] {
        let present = recovery.presentFactors
        var sentences: [String] = []
        let clauses = [hrv(recovery, present), restingHeartRate(recovery, present), sleep(recovery, present)].compactMap { $0 }
        if !clauses.isEmpty {
            sentences.append(sentence(from: clauses))
        }
        if let missing = missing(present) {
            sentences.append(missing)
        }
        // Avec la VFC présente, la ligne de base compte déjà au moins 5 nuits : le pluriel est sûr.
        if present.contains(.hrv), case .calibrating(let nights) = recovery.calibration {
            sentences.append(String(localized: "Ta ligne de base se construit encore : \(nights) nuits sur 14.", bundle: .module))
        }
        return sentences
    }

    /// « Ta variabilité …, ta fréquence … et tu … » : les propositions jointes, la première lettre en capitale.
    private static func sentence(from clauses: [String]) -> String {
        let joined = WhyContent.list(clauses)
        return joined.prefix(1).uppercased() + joined.dropFirst() + "."
    }

    private static func hrv(_ recovery: DailyRecovery, _ present: [Factor]) -> String? {
        guard present.contains(.hrv), let sdnn = recovery.sdnnMs, let baseline = recovery.sdnnBaselineMs, baseline > 0 else {
            return nil
        }
        let change = WhyContent.rounded((sdnn - baseline) / baseline * 100)
        let percent = "\(abs(change)) %"
        if change <= -hrvThresholdPercent {
            return String(localized: "ta variabilité cardiaque est \(percent) sous ta moyenne de 14 jours", bundle: .module)
        }
        if change >= hrvThresholdPercent {
            return String(localized: "ta variabilité cardiaque est \(percent) au-dessus de ta moyenne de 14 jours", bundle: .module)
        }
        return String(localized: "ta variabilité cardiaque est proche de ta moyenne de 14 jours", bundle: .module)
    }

    private static func restingHeartRate(_ recovery: DailyRecovery, _ present: [Factor]) -> String? {
        guard present.contains(.restingHeartRate), let bpm = recovery.restingHeartRate,
              let baseline = recovery.restingHeartRateBaseline else { return nil }
        let change = WhyContent.rounded(bpm - baseline)
        let amount = "\(abs(change)) bpm"
        if change >= heartRateThresholdBpm {
            return String(localized: "ta fréquence au repos a pris \(amount)", bundle: .module)
        }
        if change <= -heartRateThresholdBpm {
            return String(localized: "ta fréquence au repos a baissé de \(amount)", bundle: .module)
        }
        return String(localized: "ta fréquence au repos est stable", bundle: .module)
    }

    private static func sleep(_ recovery: DailyRecovery, _ present: [Factor]) -> String? {
        guard present.contains(.sleep), let minutes = recovery.asleepMinutes else { return nil }
        let duration = PulseFormat.duration(minutes: minutes)
        if minutes < shortSleepMinutes {
            return String(localized: "tu n'as dormi que \(duration)", bundle: .module)
        }
        return String(localized: "tu as dormi \(duration)", bundle: .module)
    }

    /// Quand un seul facteur manque, ce sur quoi le score repose à la place.
    private static func missing(_ present: [Factor]) -> String? {
        let absent = Factor.allCases.filter { !present.contains($0) }
        guard absent.count == 1, let factor = absent.first else { return nil }
        switch factor {
        case .hrv:
            return String(localized: "Pas de variabilité cette nuit : le score repose sur le sommeil et la fréquence au repos.",
                          bundle: .module)
        case .restingHeartRate:
            return String(localized: "Pas de fréquence au repos cette nuit : le score repose sur la variabilité et le sommeil.",
                          bundle: .module)
        case .sleep:
            return String(localized: "Pas de sommeil enregistré cette nuit : le score repose sur la variabilité et la fréquence au repos.",
                          bundle: .module)
        }
    }

    // MARK: - Conclusion

    /// La conclusion qui parle de la séance ne vaut que pour une séance de musculation allégée, ou prévue telle quelle au score
    /// optimal ; un jour de repos, de course, sans programme ou après « Séance d'origine » garde la phrase neutre.
    private static func conclusion(_ category: RecoveryCategory, session: TodaySession) -> [String] {
        let isStrength = if case .strength = session.plannedDay { true } else { false }
        if isStrength, session.status == .adjusted || (session.status == .planned && category == .optimal) {
            return [sessionConclusion(category)]
        }
        var sentences = [neutralConclusion(category)]
        if session.status == .restored {
            sentences.append(String(localized: "Tu as gardé la séance d'origine.", bundle: .module))
        }
        return sentences
    }

    private static func sessionConclusion(_ category: RecoveryCategory) -> String {
        switch category {
        case .optimal:
            String(localized: "Tu es en pleine forme : la séance prévue reste telle quelle.", bundle: .module)
        case .normal:
            String(localized: "Ta récupération est correcte : la séance reste la même, avec un peu plus de repos.", bundle: .module)
        case .moderateFatigue:
            String(localized: "Ton système nerveux est sous tension : la séance est allégée.", bundle: .module)
        case .overreached:
            String(localized: "Ton corps demande du repos : mobilité douce ou repos complet aujourd'hui.", bundle: .module)
        }
    }

    private static func neutralConclusion(_ category: RecoveryCategory) -> String {
        switch category {
        case .optimal:
            String(localized: "Tu es en pleine forme.", bundle: .module)
        case .normal:
            String(localized: "Ta récupération est correcte.", bundle: .module)
        case .moderateFatigue:
            String(localized: "Ton système nerveux est sous tension : vas-y doucement aujourd'hui.", bundle: .module)
        case .overreached:
            String(localized: "Ton corps demande du repos : mobilité douce ou repos complet aujourd'hui.", bundle: .module)
        }
    }
}
