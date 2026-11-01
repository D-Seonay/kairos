import Foundation

/// Les trois questions du check-in du matin. Chaque réponse vaut 0 à 4, 4 étant la meilleure pour la récupération.
public enum CheckInQuestion: CaseIterable, Sendable, Hashable {
    case sleep
    case pain
    case motivation

    public var title: String {
        switch self {
        case .sleep: String(localized: "Ton sommeil cette nuit", bundle: .module)
        case .pain: String(localized: "Courbatures et douleurs", bundle: .module)
        case .motivation: String(localized: "Motivation à t'entraîner", bundle: .module)
        }
    }

    /// Les réponses dans l'ordre affiché, avec la valeur que lit le moteur de score.
    public var options: [(label: String, value: Int)] {
        switch self {
        case .sleep:
            [
                (String(localized: "Mauvais", bundle: .module), 0),
                (String(localized: "Moyen", bundle: .module), 1),
                (String(localized: "Correct", bundle: .module), 2),
                (String(localized: "Bon", bundle: .module), 3),
                (String(localized: "Excellent", bundle: .module), 4)
            ]
        case .pain:
            [
                (String(localized: "Aucune", bundle: .module), 4),
                (String(localized: "Légères", bundle: .module), 3),
                (String(localized: "Modérées", bundle: .module), 2),
                (String(localized: "Marquées", bundle: .module), 1),
                (String(localized: "Douleur aiguë", bundle: .module), 0)
            ]
        case .motivation:
            [
                (String(localized: "Zéro", bundle: .module), 0),
                (String(localized: "Faible", bundle: .module), 1),
                (String(localized: "Moyenne", bundle: .module), 2),
                (String(localized: "Bonne", bundle: .module), 3),
                (String(localized: "À fond", bundle: .module), 4)
            ]
        }
    }
}
