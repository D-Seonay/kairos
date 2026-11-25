import PulseDesignSystem
import SwiftUI

/// La zone du ratio de charge aiguë sur chronique, aux bornes d'`ACWRZone` du moteur (que les widgets ne lisent pas) :
/// sous 0,8, jusqu'à 1,3, sous 1,5, au-delà.
public enum WidgetLoadZone: Sendable, Equatable {
    case undertraining
    case optimal
    case elevated
    case risk

    public init(ratio: Double) {
        if ratio < 0.8 {
            self = .undertraining
        } else if ratio <= 1.3 {
            self = .optimal
        } else if ratio < 1.5 {
            self = .elevated
        } else {
            self = .risk
        }
    }

    /// La zone en toutes lettres, comme sur la carte de l'accueil.
    public var text: String {
        switch self {
        case .undertraining: String(localized: "Sous-entraînement", bundle: .module)
        case .optimal: String(localized: "Zone optimale", bundle: .module)
        case .elevated: String(localized: "Charge élevée", bundle: .module)
        case .risk: String(localized: "Risque de blessure", bundle: .module)
        }
    }

    public var isOptimal: Bool { self == .optimal }

    /// La couleur du texte de zone, celle de la pastille de la carte Charge de l'accueil : l'encre pour la zone optimale, le
    /// gris pour une charge élevée, le seul signal pour le risque de blessure, l'ardoise pour le sous-entraînement.
    public var tint: Color {
        switch self {
        case .undertraining: PulsePalette.run
        case .optimal: PulsePalette.ok
        case .elevated: PulsePalette.warn
        case .risk: PulsePalette.bad
        }
    }
}
