import PulseDomain
import SwiftUI

/// Le nom et la couleur d'une phase de sommeil, communs à l'écran Nuit et aux barres de Stats. Le papier étant le thème clair,
/// forcé dans l'app, chaque couleur atteint 3:1 sur le fond et la carte ; le nom est toujours écrit à côté.
public extension SleepStage {
    /// Les rangées de l'hypnogramme, de haut en bas.
    static let chartOrder: [SleepStage] = [.awake, .rem, .core, .deep]

    var displayName: String {
        switch self {
        case .deep: String(localized: "Profond", bundle: .module)
        case .core: String(localized: "Léger", bundle: .module)
        case .rem: String(localized: "Paradoxal", bundle: .module)
        case .awake: String(localized: "Éveil", bundle: .module)
        case .asleepUnspecified: String(localized: "Endormi", bundle: .module)
        case .inBed: String(localized: "Au lit", bundle: .module)
        }
    }

    var colorRGBA: PulseRGBA {
        switch self {
        case .deep: PulseRGBA(hex: 0x1E3A8A)
        case .core: PulseRGBA(hex: 0x2563EB)
        case .rem: PulseRGBA(hex: 0x7C3AED)
        case .awake: PulseRGBA(hex: 0xC2410C)
        case .asleepUnspecified: PulseRGBA(hex: 0x57554F)
        case .inBed: PulseRGBA(hex: 0x68655F)
        }
    }

    var color: Color { Color(colorRGBA) }
}
