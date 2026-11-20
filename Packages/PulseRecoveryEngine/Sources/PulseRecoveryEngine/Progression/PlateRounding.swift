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

    /// Charge faisable juste en dessous de `weightKg`, au centième : sur une barre, la plus grande `barre + 2 × n × plus petit
    /// disque` qui ne la dépasse pas (jamais moins que la barre) ; ailleurs, le multiple de l'incrément juste en dessous, ou la
    /// charge telle quelle sans incrément.
    public static func floorLoad(_ weightKg: Double, increment: Double, rounding: WeightRounding) -> Double {
        switch rounding {
        case .plates(let barKg, let smallestPlateKg) where smallestPlateKg > 0:
            let pairs = max(0, ((weightKg - barKg) / (2 * smallestPlateKg) + 1e-9).rounded(.down))
            return cents(barKg + 2 * pairs * smallestPlateKg)
        default:
            guard increment > 0 else { return cents(weightKg) }
            return cents((weightKg / increment + 1e-9).rounded(.down) * increment)
        }
    }

    /// Charge faisable la plus proche de `weightKg`, au centième : même règle que `floorLoad`, arrondie au plus proche.
    public static func nearestLoad(_ weightKg: Double, increment: Double, rounding: WeightRounding) -> Double {
        switch rounding {
        case .plates(let barKg, let smallestPlateKg) where smallestPlateKg > 0:
            let pairs = max(0, ((weightKg - barKg) / (2 * smallestPlateKg)).rounded())
            return cents(barKg + 2 * pairs * smallestPlateKg)
        default:
            guard increment > 0 else { return cents(weightKg) }
            return cents((weightKg / increment).rounded() * increment)
        }
    }

    /// Une charge au centième près, pour que 0,6 × 50 donne bien 30.
    static func cents(_ weightKg: Double) -> Double {
        (weightKg * 100).rounded() / 100
    }
}
