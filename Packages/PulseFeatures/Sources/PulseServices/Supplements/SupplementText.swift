import Foundation
import PulseDomain

/// Les textes des compléments : dose, heure, moment. `PulseFormat` (design system) n'est pas accessible d'ici : les nombres et
/// les heures sont formatés à la française sur place.
public enum SupplementText {
    private static let french = Locale(identifier: "fr_FR")

    /// 1 000 ; 2,5 ; 5 : à la française, sans « ,0 ».
    public static func number(_ value: Double) -> String {
        value.formatted(.number.locale(french).precision(.fractionLength(0...2)))
    }

    /// « 5 g », « 1 000 UI », « 25 µg », « 2 doses ».
    public static func dose(_ dose: Double, unit: DoseUnit) -> String {
        let value = number(dose)
        return switch unit {
        case .gram: String(localized: "\(value) g", bundle: .module)
        case .mg: String(localized: "\(value) mg", bundle: .module)
        case .microgram: String(localized: "\(value) µg", bundle: .module)
        case .iu: String(localized: "\(value) UI", bundle: .module)
        case .ml: String(localized: "\(value) ml", bundle: .module)
        case .serving where dose == 1: String(localized: "1 dose", bundle: .module)
        case .serving: String(localized: "\(value) doses", bundle: .module)
        }
    }

    public static func dose(of supplement: Supplement) -> String {
        dose(supplement.dose, unit: supplement.unit)
    }

    /// 480 → « 8:00 ».
    public static func time(minutes: Int) -> String {
        let clamped = min(max(0, minutes), 24 * 60 - 1)
        return "\(clamped / 60):\(clamped % 60 < 10 ? "0" : "")\(clamped % 60)"
    }

    /// Le libellé court d'un moment de prise : « Heure fixe », « Avant la séance »…
    public static func timing(_ timing: SupplementTiming) -> String {
        switch timing {
        case .fixedTime: String(localized: "Heure fixe", bundle: .module)
        case .beforeWorkout: String(localized: "Avant la séance", bundle: .module)
        case .afterWorkout: String(localized: "Après la séance", bundle: .module)
        case .bedtime: String(localized: "Au coucher", bundle: .module)
        }
    }

    /// Le titre d'un moment de la journée.
    public static func moment(_ moment: SupplementMoment) -> String {
        switch moment {
        case .morning: String(localized: "Matin", bundle: .module)
        case .afternoon: String(localized: "Après-midi", bundle: .module)
        case .workout: String(localized: "Autour de la séance", bundle: .module)
        case .evening: String(localized: "Soir", bundle: .module)
        }
    }

    /// « 8:00 », « 17:30 · 30 min avant la séance », « Après la séance », « 22:30 · au coucher ».
    public static func planned(_ item: SupplementDueItem) -> String {
        let time = time(minutes: item.plannedMinutes)
        switch item.supplement.timing {
        case .fixedTime: return time
        case .beforeWorkout: return String(localized: "\(time) · 30 min avant la séance", bundle: .module)
        case .afterWorkout:
            return item.isWorkoutFinished ? String(localized: "\(time) · après la séance", bundle: .module)
                : String(localized: "Après la séance", bundle: .module)
        case .bedtime: return String(localized: "\(time) · au coucher", bundle: .module)
        }
    }

    /// Le corps du rappel : « 1 000 UI · c'est l'heure de ta prise ».
    public static func reminderBody(_ supplement: Supplement) -> String {
        String(localized: "\(dose(of: supplement)) · c'est l'heure de ta prise", bundle: .module)
    }
}
