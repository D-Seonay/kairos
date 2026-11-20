import Foundation

/// Les types Apple Santé où Pulse écrit les prises (spec V1 §5.3) ; la valeur brute est celle de `Supplement.healthKitType`.
public enum SupplementHealthType: String, Sendable, Codable, CaseIterable {
    case vitaminD = "dietaryVitaminD"
    case magnesium = "dietaryMagnesium"
    case caffeine = "dietaryCaffeine"
    case protein = "dietaryProtein"
}

extension Supplement {
    /// Le type Apple Santé du complément ; `nil` sans type, ou avec une valeur inconnue.
    public var healthType: SupplementHealthType? {
        healthKitType.flatMap(SupplementHealthType.init(rawValue:))
    }
}
