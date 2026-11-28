import Foundation
import PulseDesignSystem
import PulseDomain
import PulseRecoveryEngine
import PulseServices

/// Ce que l'écran « Pourquoi » dit du calcul d'un score mesuré : sur combien de nuits repose la ligne de base VFC (et combien ont
/// été écartées), d'où vient la FC au repos, la dette de sommeil, puis le ressenti du matin, à part. Pur.
enum WhyDetails {
    /// Une ligne par signal présent, dans l'ordre VFC, FC au repos, sommeil ; vide pour un score estimé ou sans `insight`.
    static func lines(recovery: DailyRecovery, insight: RecoveryInsight?) -> [String] {
        guard !recovery.isEstimated, let insight else { return [] }
        let present = recovery.presentFactors
        var lines: [String] = []
        if present.contains(.hrv), let baseline = baseline(insight) {
            lines.append(baseline)
        }
        if present.contains(.restingHeartRate), let source = insight.restingHeartRateSource {
            lines.append(restingHeartRate(source))
        }
        if present.contains(.sleep), let debt = insight.sleepDebtMinutes {
            lines.append(sleepDebt(minutes: debt))
        }
        return lines
    }

    /// « Ligne de base VFC : médiane de tes 14 nuits d'avant », avec les nuits écartées faute d'assez de mesures.
    static func baseline(_ insight: RecoveryInsight) -> String? {
        let nights = insight.hrvBaselineNights
        guard nights > 0 else { return nil }
        switch insight.hrvSetAsideNights {
        case 0:
            return String(localized: "Ligne de base VFC : médiane de tes \(nights) nuits d'avant.", bundle: .module)
        case 1:
            return String(localized: "Ligne de base VFC : médiane de \(nights) nuits ; 1 nuit écartée, trop peu mesurée.",
                          bundle: .module)
        case let setAside:
            return String(localized: "Ligne de base VFC : médiane de \(nights) nuits ; \(setAside) nuits écartées, trop peu mesurées.",
                          bundle: .module)
        }
    }

    static func restingHeartRate(_ source: RestingHeartRateSource) -> String {
        switch source {
        case .overnightLowest:
            String(localized: "FC au repos : la plus basse de ta nuit, comparée à celle de tes 7 nuits d'avant.", bundle: .module)
        case .appleNearWake:
            String(localized: """
                FC au repos : la valeur d'Apple Santé la plus proche de ton réveil, faute d'assez de mesures pendant ton sommeil.
                """, bundle: .module)
        }
    }

    /// « Dette de sommeil : 3 h 40 sur 7 nuits, qui compte pour 30 % du sommeil. »
    static func sleepDebt(minutes: Int) -> String {
        let share = Int((SleepDebt.shareOfSleepFactor * 100).rounded())
        guard minutes > 0 else {
            return String(localized: "Pas de dette de sommeil sur 7 nuits : elle compte pour \(share) % du sommeil.", bundle: .module)
        }
        let debt = PulseFormat.duration(minutes: minutes)
        return String(localized: "Dette de sommeil : \(debt) sur 7 nuits, qui compte pour \(share) % du sommeil.", bundle: .module)
    }

    /// « Ressenti du matin : −2 points → 56 » ; à part de la formule, qui reste celle de la mesure. `nil` sans ressenti.
    static func feeling(recovery: DailyRecovery, checkIn: CheckIn?) -> String? {
        guard let feeling = recovery.feeling(checkIn) else { return nil }
        let points = WhyContent.rounded(feeling.points)
        let score = WhyContent.rounded(feeling.score)
        let cap = Int(FeelingAdjustment.cap)
        switch points {
        case 0:
            return String(localized: "Ressenti du matin : aucun point de plus, le score reste dans sa catégorie (± \(cap) au plus).",
                          bundle: .module)
        case let positive where positive > 0:
            return String(localized: "Ressenti du matin : +\(positive) → \(score) (± \(cap) au plus).", bundle: .module)
        case let negative:
            return String(localized: "Ressenti du matin : −\(-negative) → \(score) (± \(cap) au plus).", bundle: .module)
        }
    }
}
