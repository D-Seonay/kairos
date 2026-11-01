import PulseDomain

/// Les 30 régions des silhouettes MuscleMap, nommées comme les variables `--mm-<nom>` de `maquette.html`.
public enum MuscleMapRegion: String, CaseIterable, Sendable {
    case abs
    case adductors
    case biceps
    case calves
    case chest
    case deltoids
    case forearm
    case frontDeltoid
    case gluteal
    case hamstring
    case hipFlexors
    case innerQuad
    case lowerAbs
    case lowerBack
    case lowerChest
    case lowerTrapezius
    case obliques
    case outerQuad
    case quadriceps
    case rearDeltoid
    case rhomboids
    case rotatorCuff
    case serratus
    case tibialis
    case trapezius
    case triceps
    case upperAbs
    case upperBack
    case upperChest
    case upperTrapezius

    /// Vrai pour les régions dont le repli est `transparent` dans la maquette : dessinées seulement quand elles sont allumées.
    public var isOverlay: Bool {
        switch self {
        case .frontDeltoid, .hipFlexors, .innerQuad, .lowerAbs, .lowerChest, .lowerTrapezius, .outerQuad,
             .rearDeltoid, .rhomboids, .serratus, .upperAbs, .upperChest, .upperTrapezius:
            true
        default:
            false
        }
    }
}

public extension Muscle {
    /// Les régions de la carte que ce muscle allume (spec M3 §6.3).
    var mapRegions: [MuscleMapRegion] {
        switch self {
        case .chest: [.chest]
        case .frontDelts: [.frontDeltoid]
        case .sideDelts: [.deltoids]
        case .rearDelts: [.rearDeltoid]
        case .traps: [.trapezius]
        case .lats, .upperBack: [.upperBack]
        case .lowerBack: [.lowerBack]
        case .biceps: [.biceps]
        case .triceps: [.triceps]
        case .forearms: [.forearm]
        case .abs: [.abs]
        case .obliques: [.obliques]
        case .quads: [.quadriceps]
        case .hamstrings: [.hamstring]
        case .glutes, .abductors: [.gluteal]
        case .adductors: [.adductors]
        case .calves: [.calves]
        case .hipFlexors: [.hipFlexors]
        }
    }
}
