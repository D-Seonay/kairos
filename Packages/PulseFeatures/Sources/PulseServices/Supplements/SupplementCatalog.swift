import Foundation
import PulseDomain

/// Une suggestion du formulaire (spec M5 §10) : elle préremplit tout sauf la dose, que Pulse ne propose jamais.
public struct SupplementSuggestion: Sendable, Equatable, Identifiable {
    public var id: String
    public var name: String
    public var form: SupplementForm
    public var unit: DoseUnit
    public var timing: SupplementTiming
    public var timeOfDayMinutes: Int?
    public var days: SupplementDays
    public var healthType: SupplementHealthType?
}

/// Un conseil factuel sur le moment de prise (spec M5 §9), jamais sur la dose.
public struct SupplementAdvice: Sendable, Equatable, Identifiable {
    public enum Kind: String, Sendable {
        case caffeineLate
        case vitaminDWithMeal
        case ironAndCoffee
        case creatineRegularity
    }

    public var kind: Kind
    public var title: String
    public var text: String

    public var id: Kind { kind }
}

/// Les suggestions courantes et les conseils de moment de prise.
public enum SupplementCatalog {
    /// La caféine prise à partir de 16:00 peut réduire le sommeil profond.
    public static let caffeineCutoffMinutes = 16 * 60

    public static let suggestions: [SupplementSuggestion] = [
        SupplementSuggestion(id: "creatine", name: String(localized: "Créatine", bundle: .module), form: .powder, unit: .gram,
                             timing: .fixedTime, timeOfDayMinutes: 8 * 60, days: .everyDay, healthType: nil),
        SupplementSuggestion(id: "whey", name: String(localized: "Whey", bundle: .module), form: .powder, unit: .gram,
                             timing: .afterWorkout, days: .trainingDays, healthType: .protein),
        SupplementSuggestion(id: "vitamin-d", name: String(localized: "Vitamine D3", bundle: .module), form: .capsule, unit: .iu,
                             timing: .fixedTime, timeOfDayMinutes: 8 * 60, days: .everyDay, healthType: .vitaminD),
        SupplementSuggestion(id: "magnesium", name: String(localized: "Magnésium", bundle: .module), form: .capsule, unit: .mg,
                             timing: .bedtime, timeOfDayMinutes: 22 * 60 + 30, days: .everyDay, healthType: .magnesium),
        SupplementSuggestion(id: "caffeine", name: String(localized: "Caféine", bundle: .module), form: .capsule, unit: .mg,
                             timing: .beforeWorkout, days: .trainingDays, healthType: .caffeine),
        SupplementSuggestion(id: "omega-3", name: String(localized: "Oméga-3", bundle: .module), form: .capsule, unit: .mg,
                             timing: .fixedTime, timeOfDayMinutes: 8 * 60, days: .everyDay, healthType: nil),
        SupplementSuggestion(id: "iron", name: String(localized: "Fer", bundle: .module), form: .tablet, unit: .mg,
                             timing: .fixedTime, timeOfDayMinutes: 8 * 60, days: .everyDay, healthType: nil),
        SupplementSuggestion(id: "zinc", name: String(localized: "Zinc", bundle: .module), form: .tablet, unit: .mg,
                             timing: .bedtime, timeOfDayMinutes: 22 * 60 + 30, days: .everyDay, healthType: nil),
        SupplementSuggestion(id: "electrolytes", name: String(localized: "Électrolytes", bundle: .module), form: .powder,
                             unit: .serving, timing: .beforeWorkout, days: .trainingDays, healthType: nil)
    ]

    /// Les conseils pour les compléments dus aujourd'hui, un par sorte, dans l'ordre des compléments.
    public static func advice(for items: [SupplementDueItem]) -> [SupplementAdvice] {
        var seen: Set<SupplementAdvice.Kind> = []
        return items.compactMap { item in
            guard let advice = advice(for: item), seen.insert(advice.kind).inserted else { return nil }
            return advice
        }
    }

    static func advice(for item: SupplementDueItem) -> SupplementAdvice? {
        let supplement = item.supplement
        let name = folded(supplement.name)
        if supplement.healthType == .caffeine || name.contains("cafeine") || name.contains("caffeine") || words(name).contains("cafe") {
            guard item.plannedMinutes >= caffeineCutoffMinutes else { return nil }
            let time = SupplementText.time(minutes: item.plannedMinutes)
            return SupplementAdvice(kind: .caffeineLate, title: String(localized: "Caféine et sommeil", bundle: .module),
                                    text: String(localized: """
                                        Prise prévue à \(time). La caféine prise après 16 h peut réduire ton sommeil profond, qui \
                                        compte dans ton score du lendemain.
                                        """, bundle: .module))
        }
        if supplement.healthType == .vitaminD || name.contains("vitamine d") || name.contains("vitamin d") {
            return SupplementAdvice(kind: .vitaminDWithMeal, title: String(localized: "Vitamine D", bundle: .module),
                                    text: String(localized: "La vitamine D s'absorbe mieux avec un repas qui contient des graisses.",
                                                 bundle: .module))
        }
        if words(name).contains("fer") || words(name).contains("iron") {
            return SupplementAdvice(kind: .ironAndCoffee, title: String(localized: "Fer", bundle: .module),
                                    text: String(localized: "Le café et le thé réduisent l'absorption du fer : espace-les d'une heure.",
                                                 bundle: .module))
        }
        if name.contains("creatine") {
            return SupplementAdvice(kind: .creatineRegularity, title: String(localized: "Créatine", bundle: .module),
                                    text: String(localized: "La créatine agit par accumulation : la régularité compte plus que le moment.",
                                                 bundle: .module))
        }
        return nil
    }

    /// En minuscules, sans accents.
    static func folded(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "fr_FR")).lowercased()
    }

    private static func words(_ text: String) -> Set<String> {
        Set(text.split { !$0.isLetter }.map(String.init))
    }
}
