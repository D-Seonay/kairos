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

    // MARK: - Facteurs

    private static func sleep(_ recovery: DailyRecovery) -> FactorDisplay {
        let title = String(localized: "Sommeil", bundle: .module)
        guard let minutes = recovery.asleepMinutes, !recovery.missingFactors.contains(.sleep) else {
            return missing(.sleep, title: title, detail: noDataDetail)
        }
        let detail: String
        if let deep = recovery.deepMinutes, minutes > 0 {
            let share = Int((Double(deep) / Double(minutes) * 100).rounded())
            let percent = "\(share) %"
            detail = String(localized: "profond \(percent)", bundle: .module)
        } else {
            detail = String(localized: "phases inconnues", bundle: .module)
        }
        return FactorDisplay(factor: .sleep, title: title, value: PulseFormat.duration(minutes: minutes), detail: detail, isMissing: false)
    }

    private static func hrv(_ recovery: DailyRecovery) -> FactorDisplay {
        let title = String(localized: "Variabilité", bundle: .module)
        guard let value = recovery.sdnnMs, !recovery.missingFactors.contains(.hrv) else {
            return missing(.hrv, title: title, detail: pendingBaselineDetail(recovery) ?? noDataDetail)
        }
        let detail = recovery.sdnnBaselineMs.flatMap { baseline -> String? in
            guard baseline > 0 else { return nil }
            let change = PulseFormat.signedPercent((value - baseline) / baseline * 100)
            return String(localized: "\(change) vs 14 j", bundle: .module)
        }
        return FactorDisplay(factor: .hrv, title: title, value: PulseFormat.integer(value, unit: "ms"),
                             detail: detail ?? baselineInProgress, isMissing: false)
    }

    private static func restingHeartRate(_ recovery: DailyRecovery) -> FactorDisplay {
        let title = String(localized: "FC repos", bundle: .module)
        guard let value = recovery.restingHeartRate, !recovery.missingFactors.contains(.restingHeartRate) else {
            return missing(.restingHeartRate, title: title, detail: noDataDetail)
        }
        let detail = recovery.restingHeartRateBaseline.map { PulseFormat.signedInteger(value - $0, unit: "bpm") }
        return FactorDisplay(factor: .restingHeartRate, title: title, value: PulseFormat.integer(value, unit: nil),
                             detail: detail ?? baselineInProgress, isMissing: false)
    }

    private static func missing(_ factor: Factor, title: String, detail: String) -> FactorDisplay {
        FactorDisplay(factor: factor, title: title, value: dash, detail: detail, isMissing: true)
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
