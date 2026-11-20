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
