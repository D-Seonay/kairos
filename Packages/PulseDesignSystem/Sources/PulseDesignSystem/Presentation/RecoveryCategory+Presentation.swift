import PulseDomain
import SwiftUI

/// Le ton d'une catégorie : la couleur ne porte jamais seule l'information, le nom est toujours écrit.
public enum CategoryTone: Sendable {
    case positive
    case caution
    case critical

    /// Sur la dalle tramée, les teintes `opalOK`… restent lisibles par-dessus la trame.
    public func color(onOpal: Bool) -> Color {
        switch self {
        case .positive: onOpal ? PulsePalette.opalOK : PulsePalette.ok
        case .caution: onOpal ? PulsePalette.opalWarn : PulsePalette.warn
        case .critical: onOpal ? PulsePalette.opalBad : PulsePalette.bad
        }
    }
}

public extension RecoveryCategory {
    var localizedName: String {
        switch self {
        case .optimal: String(localized: "Forme optimale", bundle: .module)
        case .normal: String(localized: "Forme normale", bundle: .module)
        case .moderateFatigue: String(localized: "Fatigue modérée", bundle: .module)
        case .overreached: String(localized: "Surmenage", bundle: .module)
        }
    }

    var tone: CategoryTone {
        switch self {
        case .optimal, .normal: .positive
        case .moderateFatigue: .caution
        case .overreached: .critical
        }
    }
}
