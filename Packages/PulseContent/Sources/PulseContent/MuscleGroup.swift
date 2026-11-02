import Foundation
import PulseDomain

/// Les six grands groupes musculaires de la bibliothèque et de la fiche d'exercice.
public enum MuscleGroup: String, Sendable, CaseIterable {
    case chest, back, shoulders, arms, legs, core

    public init(_ muscle: Muscle) {
        switch muscle {
        case .chest: self = .chest
        case .lats, .upperBack, .lowerBack, .traps: self = .back
        case .frontDelts, .sideDelts, .rearDelts: self = .shoulders
        case .biceps, .triceps, .forearms: self = .arms
        case .quads, .hamstrings, .glutes, .adductors, .abductors, .calves, .hipFlexors: self = .legs
        case .abs, .obliques: self = .core
        }
    }

    public var localizedName: String {
        switch self {
        case .chest: String(localized: "Pectoraux", bundle: .module)
        case .back: String(localized: "Dos", bundle: .module)
        case .shoulders: String(localized: "Épaules", bundle: .module)
        case .arms: String(localized: "Bras", bundle: .module)
        case .legs: String(localized: "Jambes", bundle: .module)
        case .core: String(localized: "Tronc", bundle: .module)
        }
    }
}
