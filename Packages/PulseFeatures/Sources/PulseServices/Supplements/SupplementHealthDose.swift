import Foundation
import PulseDomain

/// La dose d'une prise dans l'unité de son type Apple Santé (spec M5 §6) : µg pour la vitamine D, mg pour le magnésium et la
/// caféine, g pour les protéines. `nil` quand l'unité ne se convertit pas (ml, dose) : rien n'est écrit.
public enum SupplementHealthDose {
    /// 1 µg de vitamine D vaut 40 UI.
    static let vitaminDUnitsPerMicrogram = 40.0

    public static func amount(dose: Double, unit: DoseUnit, type: SupplementHealthType) -> Double? {
        guard dose > 0 else { return nil }
        if unit == .iu { return type == .vitaminD ? dose / vitaminDUnitsPerMicrogram : nil }
        guard let from = exponent(of: unit) else { return nil }
        // Puissance de dix vers l'unité du type, sans passer par le gramme : 0,3 g donnent 300 mg tout rond.
        return dose * pow(10, Double(from - targetExponent(of: type)))
    }

    /// La puissance de dix d'une unité de masse en grammes ; `nil` hors masse.
    private static func exponent(of unit: DoseUnit) -> Int? {
        switch unit {
        case .gram: 0
        case .mg: -3
        case .microgram: -6
        case .iu, .ml, .serving: nil
        }
    }

    private static func targetExponent(of type: SupplementHealthType) -> Int {
        switch type {
        case .vitaminD: -6
        case .magnesium, .caffeine: -3
        case .protein: 0
        }
    }

    /// Ce que le complément écrirait à chaque prise ; `nil` sans type ou sans unité convertible.
    public static func entryAmount(for supplement: Supplement) -> Double? {
        guard let type = supplement.healthType else { return nil }
        return amount(dose: supplement.dose, unit: supplement.unit, type: type)
    }
}
