import Foundation
import PulseDomain

extension Muscle {
    public var localizedName: String {
        switch self {
        case .chest: String(localized: "Pectoraux", bundle: .module)
        case .frontDelts: String(localized: "Deltoïdes antérieurs", bundle: .module)
        case .sideDelts: String(localized: "Deltoïdes latéraux", bundle: .module)
        case .rearDelts: String(localized: "Deltoïdes postérieurs", bundle: .module)
        case .traps: String(localized: "Trapèzes", bundle: .module)
        case .lats: String(localized: "Grands dorsaux", bundle: .module)
        case .upperBack: String(localized: "Haut du dos", bundle: .module)
        case .lowerBack: String(localized: "Lombaires", bundle: .module)
        case .biceps: String(localized: "Biceps", bundle: .module)
        case .triceps: String(localized: "Triceps", bundle: .module)
        case .forearms: String(localized: "Avant-bras", bundle: .module)
        case .abs: String(localized: "Abdominaux", bundle: .module)
        case .obliques: String(localized: "Obliques", bundle: .module)
        case .quads: String(localized: "Quadriceps", bundle: .module)
        case .hamstrings: String(localized: "Ischio-jambiers", bundle: .module)
        case .glutes: String(localized: "Fessiers", bundle: .module)
        case .adductors: String(localized: "Adducteurs", bundle: .module)
        case .abductors: String(localized: "Abducteurs", bundle: .module)
        case .calves: String(localized: "Mollets", bundle: .module)
        case .hipFlexors: String(localized: "Fléchisseurs de hanche", bundle: .module)
        }
    }
}

extension Equipment {
    public var localizedName: String {
        switch self {
        case .barbell: String(localized: "Barre", bundle: .module)
        case .ezBar: String(localized: "Barre EZ", bundle: .module)
        case .dumbbell: String(localized: "Haltères", bundle: .module)
        case .kettlebell: String(localized: "Kettlebell", bundle: .module)
        case .machine: String(localized: "Machine", bundle: .module)
        case .cable: String(localized: "Poulie", bundle: .module)
        case .smithMachine: String(localized: "Smith machine", bundle: .module)
        case .band: String(localized: "Élastique", bundle: .module)
        case .bodyweight: String(localized: "Poids du corps", bundle: .module)
        }
    }
}

extension MovementPattern {
    public var localizedName: String {
        switch self {
        case .horizontalPush: String(localized: "Poussée horizontale", bundle: .module)
        case .chestFly: String(localized: "Écarté", bundle: .module)
        case .verticalPush: String(localized: "Poussée verticale", bundle: .module)
        case .shoulderIsolation: String(localized: "Isolation épaules", bundle: .module)
        case .verticalPull: String(localized: "Tirage vertical", bundle: .module)
        case .horizontalPull: String(localized: "Tirage horizontal", bundle: .module)
        case .elbowFlexion: String(localized: "Flexion du coude", bundle: .module)
        case .elbowExtension: String(localized: "Extension du coude", bundle: .module)
        case .forearm: String(localized: "Avant-bras", bundle: .module)
        case .squat: String(localized: "Squat", bundle: .module)
        case .lunge: String(localized: "Fente", bundle: .module)
        case .hinge: String(localized: "Charnière de hanche", bundle: .module)
        case .kneeFlexion: String(localized: "Flexion du genou", bundle: .module)
        case .kneeExtension: String(localized: "Extension du genou", bundle: .module)
        case .hipAbduction: String(localized: "Abduction de hanche", bundle: .module)
        case .hipAdduction: String(localized: "Adduction de hanche", bundle: .module)
        case .calfRaise: String(localized: "Mollets", bundle: .module)
        case .coreFlexion: String(localized: "Flexion du tronc", bundle: .module)
        case .coreStability: String(localized: "Gainage", bundle: .module)
        }
    }
}

extension BodyRegion {
    public var localizedName: String {
        switch self {
        case .upper: String(localized: "Haut du corps", bundle: .module)
        case .lower: String(localized: "Bas du corps", bundle: .module)
        case .core: String(localized: "Tronc", bundle: .module)
        }
    }
}

extension LoadKind {
    public var localizedName: String {
        switch self {
        case .external: String(localized: "Charge externe", bundle: .module)
        case .bodyweight: String(localized: "Poids du corps", bundle: .module)
        case .assisted: String(localized: "Assisté", bundle: .module)
        }
    }
}
