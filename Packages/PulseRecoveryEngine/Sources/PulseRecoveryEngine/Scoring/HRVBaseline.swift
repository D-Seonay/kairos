import Foundation

/// Ligne de base VFC : moyenne et écart-type échantillon de `ln(SDNN)` sur les nuits disponibles (spec §6.2, §6.3).
public struct HRVBaseline: Sendable, Equatable {
    /// Nombre minimal de nuits valides pour construire une ligne de base.
    public static let minimumNights = 5
    /// Plancher de l'écart-type en unités log, pour éviter un z-score explosif.
    public static let standardDeviationFloor = 0.05

    public let mean: Double
    public let standardDeviation: Double
    public let nights: Int

    public init?(sdnnValuesMs: [Double]) {
        let logs = sdnnValuesMs.filter(Self.isValid).map { log($0) }
        guard logs.count >= Self.minimumNights else { return nil }
        let count = Double(logs.count)
        let mean = logs.reduce(0, +) / count
        let variance = logs.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / (count - 1)
        self.mean = mean
        self.standardDeviation = max(variance.squareRoot(), Self.standardDeviationFloor)
        self.nights = logs.count
    }

    /// Vrai si la valeur est dans `]0, 300]` ms.
    public static func isValid(sdnnMs: Double) -> Bool {
        sdnnMs > 0 && sdnnMs <= 300
    }

    public func zScore(sdnnMs: Double) -> Double {
        (log(sdnnMs) - mean) / standardDeviation
    }
}
