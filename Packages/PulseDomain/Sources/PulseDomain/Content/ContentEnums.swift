/// Groupe musculaire, aligné sur les régions de la carte musculaire (spec M2 §4.1).
public enum Muscle: String, Sendable, Codable, CaseIterable {
    case chest
    case frontDelts
    case sideDelts
    case rearDelts
    case traps
    case lats
    case upperBack
    case lowerBack
    case biceps
    case triceps
    case forearms
    case abs
    case obliques
    case quads
    case hamstrings
    case glutes
    case adductors
    case abductors
    case calves
    case hipFlexors
}

/// Matériel d'un exercice.
public enum Equipment: String, Sendable, Codable, CaseIterable {
    case barbell
    case ezBar
    case dumbbell
    case kettlebell
    case machine
    case cable
    case smithMachine
    case band
    case bodyweight
}

/// Plan de mouvement : sert au remplacement et aux alternatives (spec V1 §5.5).
public enum MovementPattern: String, Sendable, Codable, CaseIterable {
    case horizontalPush
    case chestFly
    case verticalPush
    case shoulderIsolation
    case verticalPull
    case horizontalPull
    case elbowFlexion
    case elbowExtension
    case forearm
    case squat
    case lunge
    case hinge
    case kneeFlexion
    case kneeExtension
    case hipAbduction
    case hipAdduction
    case calfRaise
    case coreFlexion
    case coreStability
}

/// Haut, bas du corps ou tronc : fixe l'incrément de progression par défaut.
public enum BodyRegion: String, Sendable, Codable, CaseIterable {
    case upper
    case lower
    case core
}

/// Ce que représente le poids saisi : charge externe, lest ajouté au poids du corps, ou assistance.
public enum LoadKind: String, Sendable, Codable, CaseIterable {
    case external
    case bodyweight
    case assisted
}
