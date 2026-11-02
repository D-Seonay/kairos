/// La géométrie de la barre de charge (ACWR) : où tombe un ratio sur la barre de la maquette (`.acwr`).
public enum LoadGaugeGeometry {
    /// Les bornes des zones de la barre, en fraction de sa largeur : sous-charge, zone optimale, vigilance, risque.
    public static let zoneBounds: [Double] = [0, 0.20, 0.60, 0.78, 1]

    /// Le ratio de charge 7 j / 28 j aux bornes des zones : 0,8 et 1,3 encadrent la zone optimale, 1,5 ouvre le risque.
    private static let knots: [(ratio: Double, fraction: Double)] = [
        (0, 0), (0.8, 0.20), (1.3, 0.60), (1.5, 0.78), (2, 1)
    ]

    /// La position du ratio sur la barre, entre 0 et 1, linéaire par morceaux. Un ratio qui n'est pas un nombre compte pour 0.
    public static func fraction(ratio: Double) -> Double {
        guard !ratio.isNaN else { return 0 }
        guard let last = knots.last, ratio < last.ratio else { return 1 }
        guard let upperIndex = knots.firstIndex(where: { ratio < $0.ratio }), upperIndex > 0 else { return 0 }
        let lower = knots[upperIndex - 1]
        let upper = knots[upperIndex]
        let progress = (ratio - lower.ratio) / (upper.ratio - lower.ratio)
        return lower.fraction + progress * (upper.fraction - lower.fraction)
    }
}
