import Foundation
import PulseDesignSystem
import PulseRecoveryEngine

/// Ce que la carte « Charge d'entraînement » affiche : le ratio aigu / chronique avec sa zone en toutes lettres,
/// ou rien tant que l'historique ne couvre pas 28 jours.
enum LoadCardContent: Equatable {
    case hidden
    case ratio(value: Double, valueText: String, zoneTitle: String, advice: String)

    /// Remplace la jauge tant qu'il n'y a pas de ratio.
    static var hiddenText: String {
        String(localized: "La jauge de charge apparaîtra après 28 jours d'entraînement : elle compare ta dernière semaine à ton mois.",
               bundle: .module)
    }

    static func make(_ result: ACWRResult?) -> LoadCardContent {
        guard let result else { return .hidden }
        let (title, advice) = texts(for: result.zone)
        return .ratio(value: result.ratio, valueText: PulseFormat.decimal(result.ratio, maxFractionDigits: 2),
                      zoneTitle: title, advice: advice)
    }

    private static func texts(for zone: ACWRZone) -> (title: String, advice: String) {
        switch zone {
        case .undertraining:
            (String(localized: "Sous-entraînement", bundle: .module),
             String(localized: "Tu peux augmenter progressivement ta charge.", bundle: .module))
        case .optimal:
            (String(localized: "Zone optimale", bundle: .module),
             String(localized: "Tu peux maintenir ce rythme cette semaine.", bundle: .module))
        case .elevated:
            (String(localized: "Charge élevée", bundle: .module),
             String(localized: "Ta charge monte vite : surveille ta récupération.", bundle: .module))
        case .risk:
            (String(localized: "Risque de blessure", bundle: .module),
             String(localized: "Ta charge a bondi : allège les prochains jours.", bundle: .module))
        }
    }
}
