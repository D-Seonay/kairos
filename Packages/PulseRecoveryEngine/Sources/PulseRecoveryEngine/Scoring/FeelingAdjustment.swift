import PulseDomain

/// Le ressenti du matin quand le score est mesuré : un léger modificateur, le score mesuré reste le cœur.
///
/// - Le modificateur vaut un dixième de l'écart entre le score du check-in et le score mesuré, plafonné à ± `cap` points.
/// - Il peut faire baisser la catégorie (se sentir mal rend la séance plus prudente), jamais la faire monter : un ressenti
///   meilleur que la mesure monte le score au plus jusqu'au haut de sa catégorie. Un jour rouge ne passe donc jamais au vert.
public enum FeelingAdjustment {
    /// Le plafond du modificateur, en points.
    public static let cap = 5.0
    /// La part de l'écart ressenti / mesuré qui passe dans le score.
    static let share = 0.1

    /// Le score mesuré et ce que le ressenti y change.
    public struct Result: Sendable, Equatable {
        /// Le score mesuré, avant le ressenti.
        public var measured: Double
        /// Les points ajoutés (ou retirés) par le ressenti, plafonnés et bornés à la catégorie mesurée.
        public var points: Double
        public var score: Double { measured + points }
    }

    public static func apply(measured: Double, checkInScore: Double) -> Result {
        let raw = min(cap, max(-cap, (checkInScore - measured) * share))
        var adjusted = min(100, max(0, measured + raw))
        let category = RecoveryCategory(score: measured)
        if RecoveryCategory(score: adjusted).rank > category.rank, let ceiling = category.ceiling {
            adjusted = max(measured, ceiling)
        }
        return Result(measured: measured, points: adjusted - measured)
    }
}

extension RecoveryCategory {
    /// 0 pour le surmenage, 3 pour l'optimal.
    var rank: Int {
        switch self {
        case .overreached: 0
        case .moderateFatigue: 1
        case .normal: 2
        case .optimal: 3
        }
    }

    /// Le plus haut score entier de la catégorie (64 pour la fatigue modérée) ; `nil` pour l'optimal, qui va jusqu'à 100.
    var ceiling: Double? {
        switch self {
        case .overreached: 39
        case .moderateFatigue: 64
        case .normal: 89
        case .optimal: nil
        }
    }
}
