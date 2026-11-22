import Foundation
import PulseDesignSystem
import PulseDomain
import PulseServices

/// Les libellés des choix du formulaire.
enum SupplementLabels {
    static func form(_ form: SupplementForm) -> String {
        switch form {
        case .powder: String(localized: "Poudre", bundle: .module)
        case .capsule: String(localized: "Gélule", bundle: .module)
        case .tablet: String(localized: "Comprimé", bundle: .module)
        case .liquid: String(localized: "Liquide", bundle: .module)
        }
    }

    static func unit(_ unit: DoseUnit) -> String {
        switch unit {
        case .gram: String(localized: "g", bundle: .module)
        case .mg: String(localized: "mg", bundle: .module)
        case .microgram: String(localized: "µg", bundle: .module)
        case .iu: String(localized: "UI", bundle: .module)
        case .ml: String(localized: "ml", bundle: .module)
        case .serving: String(localized: "dose", bundle: .module)
        }
    }

    /// « 5 grammes », « 1 000 unités internationales », « 1,5 millilitre », « 2 doses » : la dose dite en toutes lettres, le singulier
    /// sous 2 comme en français.
    static func doseSpoken(_ dose: Double, unit: DoseUnit) -> String {
        let value = SupplementText.number(dose)
        let word = unitWord(unit, isSingular: abs((dose * 100).rounded() / 100) < 2)
        return String(localized: "\(value) \(word)", bundle: .module)
    }

    /// « gramme » ou « grammes » : le nom de l'unité, au singulier ou au pluriel.
    private static func unitWord(_ unit: DoseUnit, isSingular: Bool) -> String {
        let (singular, plural): (String, String) = switch unit {
        case .gram: (String(localized: "gramme", bundle: .module), String(localized: "grammes", bundle: .module))
        case .mg: (String(localized: "milligramme", bundle: .module), String(localized: "milligrammes", bundle: .module))
        case .microgram: (String(localized: "microgramme", bundle: .module), String(localized: "microgrammes", bundle: .module))
        case .iu:
            (String(localized: "unité internationale", bundle: .module), String(localized: "unités internationales", bundle: .module))
        case .ml: (String(localized: "millilitre", bundle: .module), String(localized: "millilitres", bundle: .module))
        case .serving: (String(localized: "dose", bundle: .module), String(localized: "doses", bundle: .module))
        }
        return isSingular ? singular : plural
    }

    /// « à 8 heures », « à 17 heures 30, 30 minutes avant la séance », « après la séance », « à 22 heures 30, au coucher » :
    /// l'heure prévue dite.
    static func plannedSpoken(_ item: SupplementDueItem) -> String {
        let minutes = min(max(0, item.plannedMinutes), 24 * 60 - 1)
        let time = PulseSpoken.clock(hour: minutes / 60, minute: minutes % 60)
        switch item.supplement.timing {
        case .fixedTime: return String(localized: "à \(time)", bundle: .module)
        case .beforeWorkout: return String(localized: "à \(time), 30 minutes avant la séance", bundle: .module)
        case .afterWorkout:
            if item.isWorkoutFinished { return String(localized: "à \(time), après la séance", bundle: .module) }
            return String(localized: "après la séance", bundle: .module)
        case .bedtime: return String(localized: "à \(time), au coucher", bundle: .module)
        }
    }

    /// « grammes », « unités internationales » : le nom de l'unité dit, pour la valeur du sélecteur d'unité.
    static func unitSpoken(_ unit: DoseUnit) -> String {
        switch unit {
        case .gram: String(localized: "grammes", bundle: .module)
        case .mg: String(localized: "milligrammes", bundle: .module)
        case .microgram: String(localized: "microgrammes", bundle: .module)
        case .iu: String(localized: "unités internationales", bundle: .module)
        case .ml: String(localized: "millilitres", bundle: .module)
        case .serving: String(localized: "doses", bundle: .module)
        }
    }

    /// Le sous-titre d'un moment dans le formulaire.
    static func timingDetail(_ timing: SupplementTiming) -> String {
        switch timing {
        case .fixedTime: String(localized: "À l'heure que tu choisis", bundle: .module)
        case .beforeWorkout: String(localized: "30 min avant ton heure habituelle de séance", bundle: .module)
        case .afterWorkout: String(localized: "Rappel après la fin de la séance", bundle: .module)
        case .bedtime: String(localized: "À ton heure de coucher", bundle: .module)
        }
    }

    static func timingIcon(_ timing: SupplementTiming) -> String {
        switch timing {
        case .fixedTime: "clock"
        case .beforeWorkout: "timer"
        case .afterWorkout: "dumbbell"
        case .bedtime: "moon"
        }
    }

    static func days(_ days: SupplementDays) -> String {
        switch days {
        case .everyDay: String(localized: "Tous les jours", bundle: .module)
        case .trainingDays: String(localized: "Jours d'entraînement", bundle: .module)
        case .custom: String(localized: "Personnalisé", bundle: .module)
        }
    }

    static func healthType(_ type: SupplementHealthType?) -> String {
        switch type {
        case nil: String(localized: "Aucun", bundle: .module)
        case .vitaminD: String(localized: "Vitamine D", bundle: .module)
        case .magnesium: String(localized: "Magnésium", bundle: .module)
        case .caffeine: String(localized: "Caféine", bundle: .module)
        case .protein: String(localized: "Protéines", bundle: .module)
        }
    }

    static func momentIcon(_ moment: SupplementMoment) -> String {
        switch moment {
        case .morning: "sunrise"
        case .afternoon: "sun.max"
        case .workout: "dumbbell"
        case .evening: "moon"
        }
    }

    static let disclaimer = String(localized: """
        Pulse ne propose pas de dose. Suis la notice du produit ou l'avis d'un professionnel de santé.
        """, bundle: .module)
}
