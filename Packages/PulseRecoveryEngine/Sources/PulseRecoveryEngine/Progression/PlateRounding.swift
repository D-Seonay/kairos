/// Comment une charge se règle : par paires de disques sur une barre, ou par pas sur une machine.
public enum WeightRounding: Sendable, Equatable, Codable {
    case plates(barKg: Double, smallestPlateKg: Double)
    case increment
}

public enum PlateRounding {
    /// Charge suivante : celle d'avant plus l'incrément, arrondie vers le haut à la charge faisable.
    /// Sur une barre, la plus petite `barre + 2 × n × plus petit disque` qui atteint la cible ; ailleurs, la cible telle quelle.
    public static func nextLoad(after weightKg: Double, increment: Double, rounding: WeightRounding) -> Double {
        let target = weightKg + increment
        guard case .plates(let barKg, let smallestPlateKg) = rounding, smallestPlateKg > 0 else { return target }
        let pairs = max(0, ((target - barKg) / (2 * smallestPlateKg) - 1e-9).rounded(.up))
        return barKg + 2 * pairs * smallestPlateKg
    }
}
