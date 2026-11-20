/// Un chargement de barre : la charge totale et les disques d'un côté, du plus lourd au plus léger.
public struct PlateLoading: Sendable, Equatable {
    public let totalKg: Double
    public let perSide: [Double]

    public init(totalKg: Double, perSide: [Double]) {
        self.totalKg = totalKg
        self.perSide = perSide
    }
}

/// Ce que le calculateur rend : le chargement exact, ou les deux charges faisables qui encadrent la cible.
public enum PlateResult: Sendable, Equatable {
    case exact(PlateLoading)
    /// `lower` manque sous la barre seule, `upper` quand aucun disque ne permet de dépasser la cible.
    case approximate(lower: PlateLoading?, upper: PlateLoading?)
}

/// Le calculateur de disques (spec M4 §8.3) : les disques par côté pour une charge, avec le moins de disques possible. Chaque
/// disque disponible est supposé exister en autant de paires qu'il faut.
public enum PlateCalculator {
    public static func load(targetKg: Double, barKg: Double, availablePlatesKg: [Double]) -> PlateResult {
        let bar = PlateLoading(totalKg: PlateRounding.cents(barKg), perSide: [])
        guard targetKg > barKg - 0.001 else { return .approximate(lower: nil, upper: bar) }
        // En centièmes de kilo, pour compter juste avec 1,25 ou 0,5.
        let plates = Array(Set(availablePlatesKg.filter { $0 > 0 }.map(units))).sorted(by: >)
        let side = units((targetKg - barKg) / 2)
        let limit = side + (plates.first ?? 0)
        let fewest = fewestPlates(upTo: limit, plates: plates)

        func loading(_ sum: Int) -> PlateLoading? {
            guard let perSide = fewest[sum] else { return nil }
            return PlateLoading(totalKg: PlateRounding.cents(barKg + 2 * kilos(sum)), perSide: perSide.map(kilos))
        }

        if let exact = loading(side) { return .exact(exact) }
        let lower = (0..<side).reversed().lazy.compactMap(loading).first
        let upper = limit > side ? (side + 1...limit).lazy.compactMap(loading).first : nil
        return .approximate(lower: lower, upper: upper)
    }

    /// Pour chaque somme par côté jusqu'à `limit`, les disques les moins nombreux qui la font (les plus lourds d'abord en cas
    /// d'égalité), ou `nil` si elle est infaisable. Rendu de monnaie classique : le glouton se trompe avec 25, 15 et 10.
    private static func fewestPlates(upTo limit: Int, plates: [Int]) -> [[Int]?] {
        var best: [[Int]?] = Array(repeating: nil, count: limit + 1)
        best[0] = []
        guard limit > 0 else { return best }
        for sum in 1...limit {
            for plate in plates where plate <= sum {
                guard let rest = best[sum - plate] else { continue }
                if let current = best[sum], current.count <= rest.count + 1 { continue }
                best[sum] = ([plate] + rest).sorted(by: >)
            }
        }
        return best
    }

    private static func units(_ kilos: Double) -> Int { Int((kilos * 100).rounded()) }
    private static func kilos(_ units: Int) -> Double { Double(units) / 100 }
}
