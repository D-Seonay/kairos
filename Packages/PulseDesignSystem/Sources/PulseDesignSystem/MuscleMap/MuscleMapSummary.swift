import Foundation
import PulseDomain

/// Le résumé lu par VoiceOver pour la carte musculaire : les muscles travaillés avec leur intensité, du plus fort au plus
/// faible, puis par nom. Une fonction pure.
public enum MuscleMapSummary {
    /// « Pectoraux, intensité forte. Triceps, intensité moyenne. » ; « Aucun muscle travaillé » sans muscle.
    public static func text(levels: [Muscle: MuscleIntensity]) -> String {
        guard !levels.isEmpty else { return String(localized: "Aucun muscle travaillé", bundle: .module) }
        let french = Locale(identifier: "fr_FR")
        let ordered = levels.map { (name: $0.key.spokenName, intensity: $0.value) }.sorted { lhs, rhs in
            if lhs.intensity != rhs.intensity { return lhs.intensity > rhs.intensity }
            return lhs.name.compare(rhs.name, options: [.caseInsensitive, .diacriticInsensitive], locale: french) == .orderedAscending
        }
        return ordered.map { sentence(name: $0.name, intensity: $0.intensity) }.joined(separator: " ")
    }

    private static func sentence(name: String, intensity: MuscleIntensity) -> String {
        let word = word(for: intensity)
        return String(localized: "\(name), intensité \(word).", bundle: .module)
    }

    private static func word(for intensity: MuscleIntensity) -> String {
        switch intensity {
        case .light: String(localized: "légère", bundle: .module)
        case .moderate: String(localized: "moyenne", bundle: .module)
        case .strong: String(localized: "forte", bundle: .module)
        case .maximum: String(localized: "très forte", bundle: .module)
        }
    }
}

private extension Muscle {
    /// Les noms du catalogue du contenu, repris ici : le design system ne dépend pas de `PulseContent`.
    var spokenName: String {
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
