import Foundation
import PulseDomain

extension SleepStage {
    /// Libellé français de la phase, pour l'affichage.
    public var localizedName: String {
        switch self {
        case .inBed: String(localized: "au lit", bundle: .module)
        case .awake: String(localized: "éveillé", bundle: .module)
        case .asleepUnspecified: String(localized: "endormi", bundle: .module)
        case .core: String(localized: "léger", bundle: .module)
        case .deep: String(localized: "profond", bundle: .module)
        case .rem: String(localized: "paradoxal", bundle: .module)
        }
    }
}
