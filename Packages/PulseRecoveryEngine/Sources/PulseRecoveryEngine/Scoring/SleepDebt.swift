import PulseDomain

/// La dette de sommeil sur 7 nuits glissantes, la dernière comprise : la somme pondérée des écarts à l'objectif du profil.
///
/// - Les nuits récentes pèsent plus : la dernière compte en entier, puis chaque nuit plus ancienne d'un septième de moins (poids
///   `(7 − âge) / 7`, de 1 à 1/7). La dette ne dépasse donc jamais la somme des écarts : une seule nuit d'une heure trop courte
///   fait une heure de dette, et 30 min de moins chaque nuit en font 2 h (30 × 4).
/// - Un surplus ne rembourse qu'à moitié (`surplusRepayment`).
/// - Une nuit sans donnée ne compte ni en dette ni en surplus.
/// - La dette n'est jamais négative : des nuits longues ne mettent pas de sommeil « en réserve ».
public enum SleepDebt {
    /// Le nombre de nuits de la fenêtre, la dernière comprise.
    public static let windowNights = 7
    /// La part d'un surplus qui rembourse la dette.
    public static let surplusRepayment = 0.5
    /// La part de la dette dans le facteur sommeil ; la dernière nuit garde le reste (70 %).
    public static let shareOfSleepFactor = 0.30

    /// Une nuit de la fenêtre : son âge en jours (0 = la nuit de ce matin) et ses minutes endormies.
    public struct Night: Sendable, Equatable {
        public var age: Int
        public var asleepMinutes: Int

        public init(age: Int, asleepMinutes: Int) {
            self.age = age
            self.asleepMinutes = asleepMinutes
        }
    }

    /// La dette en minutes, arrondie ; les nuits hors de la fenêtre (âge négatif ou ≥ 7) sont ignorées.
    public static func minutes(nights: [Night], goalMinutes: Int) -> Int {
        let weighted = nights.filter { (0..<windowNights).contains($0.age) }.reduce(0.0) { total, night in
            let gap = Double(goalMinutes - night.asleepMinutes)
            return total + weight(age: night.age) * (gap < 0 ? gap * surplusRepayment : gap)
        }
        return max(0, Int(weighted.rounded()))
    }

    /// Le score de la dette, de 100 (aucune dette) à 0 (une nuit entière d'objectif en retard, ou plus).
    public static func score(debtMinutes: Int, goalMinutes: Int) -> Double {
        guard goalMinutes > 0 else { return 100 }
        return max(0, 1 - Double(debtMinutes) / Double(goalMinutes)) * 100
    }

    /// Le facteur sommeil : 70 % la dernière nuit (`SleepScorer`), 30 % la dette.
    public static func sleepFactor(lastNightScore: Double, debtScore: Double) -> Double {
        lastNightScore * (1 - shareOfSleepFactor) + debtScore * shareOfSleepFactor
    }

    static func weight(age: Int) -> Double {
        Double(windowNights - age) / Double(windowNights)
    }
}
