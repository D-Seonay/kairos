import Foundation

/// Les familles des entraînements d'Apple Santé autres que course et vélo, et l'effort qu'on leur prête sans fréquence cardiaque.
/// Les valeurs brutes sont gardées dans le cache local (`CachedHealthSample.value`) : elles ne changent pas.
public enum WorkoutFamily: Int, Sendable, CaseIterable {
    /// Natation, marche, randonnée, rameur, elliptique, ski de fond…
    case endurance = 1
    /// HIIT, cross training, boxe, corde à sauter…
    case intermittent = 2
    /// Musculation et renforcement enregistrés par une autre app.
    case strength = 3
    /// Sports collectifs, de raquette et de combat.
    case sports = 4
    /// Yoga, Pilates, étirements, retour au calme…
    case mobility = 5

    /// Le RPE compté quand l'entraînement n'a pas de fréquence cardiaque moyenne.
    public var defaultRPE: Double {
        switch self {
        case .endurance: 5
        case .intermittent: 7
        case .strength: 6
        case .sports: 6
        case .mobility: 2
        }
    }

    /// La famille gardée dans `value` ; une valeur absente ou inconnue vaut l'endurance.
    public init(storedValue: Double?) {
        self = storedValue.flatMap { Self(rawValue: Int($0)) } ?? .endurance
    }
}
