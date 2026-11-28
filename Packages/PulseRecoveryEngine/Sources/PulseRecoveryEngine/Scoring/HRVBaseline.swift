import Foundation

/// Ligne de base VFC : médiane et écart absolu médian (MAD × 1,4826) de `ln(SDNN)` sur les nuits retenues (spec §6.2, §6.3).
///
/// La médiane et le MAD ignorent une nuit aberrante (alcool, maladie, montre mal serrée) : avec 5 à 7 nuits, une moyenne et un
/// écart-type se déplaceraient et écraseraient les z-scores des jours suivants. Le facteur 1,4826 rend le MAD comparable à un
/// écart-type sur des valeurs normales.
public struct HRVBaseline: Sendable, Equatable {
    /// Nombre minimal de nuits valides pour construire une ligne de base.
    public static let minimumNights = 5
    /// Plancher de l'écart en unités log, pour éviter un z-score explosif.
    public static let spreadFloor = 0.05
    /// Le facteur qui rend le MAD comparable à un écart-type.
    static let madScale = 1.4826
    /// Une nuit dont moins de mesures SDNN tombent dans la fenêtre de sommeil est écartée de la ligne de base (nuit trop courte,
    /// montre retirée) : une seule mesure d'une minute ne dit pas la nuit. Deux, parce que l'Apple Watch n'en prend souvent que
    /// quelques-unes par nuit : un seuil plus haut écarterait trop de nuits ordinaires.
    public static let minimumSamplesPerNight = 2

    /// La médiane de `ln(SDNN)`.
    public let center: Double
    /// Le MAD de `ln(SDNN)` × 1,4826, au moins `spreadFloor`.
    public let spread: Double
    public let nights: Int

    public init?(sdnnValuesMs: [Double]) {
        let logs = sdnnValuesMs.filter(Self.isValid).map { log($0) }
        guard logs.count >= Self.minimumNights else { return nil }
        let center = Self.median(logs)
        let mad = Self.median(logs.map { abs($0 - center) })
        self.center = center
        self.spread = max(mad * Self.madScale, Self.spreadFloor)
        self.nights = logs.count
    }

    /// Vrai si la valeur est dans `]0, 300]` ms.
    public static func isValid(sdnnMs: Double) -> Bool {
        sdnnMs > 0 && sdnnMs <= 300
    }

    /// Vrai si la nuit a assez de mesures pour la ligne de base ; un nombre inconnu (`nil`, fixtures et anciennes données) passe.
    public static func isWellSampled(sampleCount: Int?) -> Bool {
        sampleCount.map { $0 >= minimumSamplesPerNight } ?? true
    }

    public func zScore(sdnnMs: Double) -> Double {
        (log(sdnnMs) - center) / spread
    }

    /// La SDNN typique de la ligne de base, en ms.
    public var typicalSDNNMs: Double {
        exp(center)
    }

    static func median(_ values: [Double]) -> Double {
        let sorted = values.sorted()
        let middle = sorted.count / 2
        return sorted.count.isMultiple(of: 2) ? (sorted[middle - 1] + sorted[middle]) / 2 : sorted[middle]
    }
}
