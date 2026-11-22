import Foundation
import PulseDesignSystem
import PulseDomain

/// Une colonne de la carte de récupération : le facteur, sa mesure de la nuit et l'écart à sa ligne de base.
public struct FactorDisplay: Sendable, Equatable {
    public var factor: Factor
    public var title: String
    public var value: String
    public var detail: String
    /// Vrai quand la nuit n'a pas fourni ce facteur : la valeur est un tiret et le détail explique pourquoi.
    public var isMissing: Bool
    /// Ce que VoiceOver lit de la colonne : le facteur, sa valeur avec son unité dite en toutes lettres et sa référence.
    public var accessibilityLabel: String
}

/// Met en mots les trois facteurs d'un score : sommeil, variabilité cardiaque, fréquence cardiaque au repos.
public enum FactorFormatter {
    /// Le nombre de nuits avec SDNN valide qu'il faut pour que la VFC compte dans le score.
    private static let hrvNightsNeeded = 5
    private static let dash = "\u{2014}"

    public static func displays(for recovery: DailyRecovery) -> [FactorDisplay] {
        [sleep(recovery), hrv(recovery), restingHeartRate(recovery)]
    }

    /// « Estimé » pour un score issu du check-in, « En calibration (9 nuits) » tant que la ligne de base VFC se construit.
    public static func marker(for recovery: DailyRecovery) -> String? {
        if recovery.isEstimated { return String(localized: "Estimé", bundle: .module) }
        if !recovery.missingFactors.contains(.hrv), case .calibrating(let nights) = recovery.calibration {
            return String(localized: "En calibration (\(nights) nuits)", bundle: .module)
        }
        return nil
    }

    /// « estimé », « en calibration, 9 nuits » : le marqueur tel que VoiceOver le dit, sans parenthèses.
    public static func spokenMarker(for recovery: DailyRecovery) -> String? {
        if recovery.isEstimated { return String(localized: "estimé", bundle: .module) }
        if !recovery.missingFactors.contains(.hrv), case .calibrating(let nights) = recovery.calibration {
            let count = PulseSpoken.count(nights, singular: String(localized: "nuit", bundle: .module),
                                          plural: String(localized: "nuits", bundle: .module))
            return String(localized: "en calibration, \(count)", bundle: .module)
        }
        return nil
    }

    // MARK: - Facteurs

    private static func sleep(_ recovery: DailyRecovery) -> FactorDisplay {
        let title = String(localized: "Sommeil", bundle: .module)
        guard let minutes = recovery.asleepMinutes, !recovery.missingFactors.contains(.sleep) else {
            return missing(.sleep, title: title, spokenTitle: title, detail: noDataDetail)
        }
        let detail: String
        let spokenDetail: String
        if let share = deepShare(minutes: minutes, deep: recovery.deepMinutes) {
            let percent = "\(share) %"
            detail = String(localized: "profond \(percent)", bundle: .module)
            spokenDetail = String(localized: "sommeil profond \(percent)", bundle: .module)
        } else {
            detail = String(localized: "phases inconnues", bundle: .module)
            spokenDetail = detail
        }
        let spoken = spokenLabel(title, PulseSpoken.duration(seconds: minutes * 60), spokenDetail)
        return FactorDisplay(factor: .sleep, title: title, value: PulseFormat.duration(minutes: minutes), detail: detail,
                             isMissing: false, accessibilityLabel: spoken)
    }

    private static func hrv(_ recovery: DailyRecovery) -> FactorDisplay {
        let title = String(localized: "Variabilité", bundle: .module)
        guard let value = recovery.sdnnMs, !recovery.missingFactors.contains(.hrv) else {
            return missing(.hrv, title: title, spokenTitle: title, detail: pendingBaselineDetail(recovery) ?? noDataDetail)
        }
        var spokenDetail = baselineInProgress
        let detail = recovery.sdnnBaselineMs.flatMap { baseline -> String? in
            guard baseline > 0 else { return nil }
            let percent = (value - baseline) / baseline * 100
            spokenDetail = spokenHRVChange(percent)
            return String(localized: "\(PulseFormat.signedPercent(percent)) vs 14 j", bundle: .module)
        }
        let spoken = spokenLabel(title, TrendTile.spokenValue(.hrv, value), spokenDetail)
        return FactorDisplay(factor: .hrv, title: title, value: PulseFormat.integer(value, unit: "ms"),
                             detail: detail ?? baselineInProgress, isMissing: false, accessibilityLabel: spoken)
    }

    private static func restingHeartRate(_ recovery: DailyRecovery) -> FactorDisplay {
        let title = String(localized: "FC repos", bundle: .module)
        let spokenTitle = String(localized: "Fréquence cardiaque au repos", bundle: .module)
        guard let value = recovery.restingHeartRate, !recovery.missingFactors.contains(.restingHeartRate) else {
            return missing(.restingHeartRate, title: title, spokenTitle: spokenTitle, detail: noDataDetail)
        }
        var spokenDetail = baselineInProgress
        let detail = recovery.restingHeartRateBaseline.map { baseline -> String in
            spokenDetail = spokenHeartRateChange(value - baseline)
            return PulseFormat.signedInteger(value - baseline, unit: "bpm")
        }
        let spoken = spokenLabel(spokenTitle, TrendTile.spokenValue(.restingHeartRate, value), spokenDetail)
        return FactorDisplay(factor: .restingHeartRate, title: title, value: PulseFormat.integer(value, unit: nil),
                             detail: detail ?? baselineInProgress, isMissing: false, accessibilityLabel: spoken)
    }

    private static func missing(_ factor: Factor, title: String, spokenTitle: String, detail: String) -> FactorDisplay {
        FactorDisplay(factor: factor, title: title, value: dash, detail: detail, isMissing: true,
                      accessibilityLabel: String(localized: "\(spokenTitle), \(detail)", bundle: .module))
    }

    // MARK: - Parlé

    private static func spokenLabel(_ title: String, _ value: String, _ detail: String) -> String {
        String(localized: "\(title), \(value), \(detail)", bundle: .module)
    }

    /// La part de sommeil profond en pour cent, `nil` sans phases ou sans sommeil.
    private static func deepShare(minutes: Int, deep: Int?) -> Int? {
        guard let deep, minutes > 0 else { return nil }
        return Int((Double(deep) / Double(minutes) * 100).rounded())
    }

    /// « 18 % de moins que sur 14 jours », « 5 % de plus que sur 14 jours », « comme sur 14 jours ».
    private static func spokenHRVChange(_ percent: Double) -> String {
        let rounded = Int(exactly: percent.rounded()) ?? 0
        let amount = "\(abs(rounded)) %"
        if rounded > 0 { return String(localized: "\(amount) de plus que sur 14 jours", bundle: .module) }
        if rounded < 0 { return String(localized: "\(amount) de moins que sur 14 jours", bundle: .module) }
        return String(localized: "comme sur 14 jours", bundle: .module)
    }

    /// « 5 battements de plus que ta ligne de base », « 1 battement de moins que ta ligne de base », « comme ta ligne de base ».
    private static func spokenHeartRateChange(_ difference: Double) -> String {
        let rounded = Int(exactly: difference.rounded()) ?? 0
        let amount = PulseSpoken.count(abs(rounded), singular: String(localized: "battement", bundle: .module),
                                       plural: String(localized: "battements", bundle: .module))
        if rounded > 0 { return String(localized: "\(amount) de plus que ta ligne de base", bundle: .module) }
        if rounded < 0 { return String(localized: "\(amount) de moins que ta ligne de base", bundle: .module) }
        return String(localized: "comme ta ligne de base", bundle: .module)
    }

    // MARK: - Textes

    private static var noDataDetail: String {
        String(localized: "pas de donnée cette nuit", bundle: .module)
    }

    private static var baselineInProgress: String {
        String(localized: "ligne de base en cours", bundle: .module)
    }

    /// La VFC absente alors que sa ligne de base n'a pas ses 5 nuits : « ligne de base en cours, 3 sur 5 nuits ».
    private static func pendingBaselineDetail(_ recovery: DailyRecovery) -> String? {
        guard case .calibrating(let nights) = recovery.calibration, nights < hrvNightsNeeded else { return nil }
        return String(localized: "ligne de base en cours, \(nights) sur \(hrvNightsNeeded) nuits", bundle: .module)
    }
}
