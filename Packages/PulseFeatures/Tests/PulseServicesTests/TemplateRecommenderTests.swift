import PulseContent
import PulseDomain
import PulseServices
import Testing

struct TemplateRecommenderTests {
    private let templates = ContentLibrary.bundled.programTemplates

    /// Le modèle est choisi pour les séances de musculation que le curseur laisse, pas pour le total de la semaine.
    @Test func recommendations() {
        #expect(TemplateRecommender.recommendedID(focus: 0.2, daysPerWeek: 3, templates: templates) == "ppl-3")
        #expect(TemplateRecommender.recommendedID(focus: 0.2, daysPerWeek: 6, templates: templates) == "ppl-6")
        #expect(TemplateRecommender.recommendedID(focus: 0.5, daysPerWeek: 3, templates: templates) == "full-body")
        #expect(TemplateRecommender.recommendedID(focus: 0.5, daysPerWeek: 4, templates: templates) == "full-body",
                "4 séances au milieu du curseur : 2 de musculation, plus près de Full Body que de Haut / Bas")
        #expect(TemplateRecommender.recommendedID(focus: 0.35, daysPerWeek: 6, templates: templates) == "upper-lower",
                "6 séances côté force : 4 de musculation")
        #expect(TemplateRecommender.recommendedID(focus: 0.9, daysPerWeek: 3, templates: templates) == "runner-strength")
    }

    @Test func templatesCountTheirStrengthDays() {
        let counts = Dictionary(uniqueKeysWithValues: templates.map { ($0.id, $0.strengthDaysPerWeek) })
        #expect(counts == ["ppl-3": 3, "ppl-6": 6, "upper-lower": 4, "full-body": 3, "runner-strength": 2])
    }

    @Test func onlyBalancedTemplatesCanBeShortened() {
        #expect(templates.filter(\.canBeShortened).map(\.id) == ["upper-lower", "full-body"])
    }

    @Test func focusThresholdsAreExclusive() {
        #expect(TemplateRecommender.focus(for: 0.34) == .strength)
        #expect(TemplateRecommender.focus(for: 0.35) == .balanced)
        #expect(TemplateRecommender.focus(for: 0.65) == .balanced)
        #expect(TemplateRecommender.focus(for: 0.66) == .endurance)
    }

    @Test func closestStrengthDayCountWins() {
        #expect(TemplateRecommender.recommendedID(focus: 0.2, daysPerWeek: 5, templates: templates) == "ppl-3",
                "4 séances de musculation : plus près de 3 que de 6")
        #expect(TemplateRecommender.recommendedID(focus: 0, daysPerWeek: 5, templates: templates) == "ppl-6")
        #expect(TemplateRecommender.recommendedID(focus: 0.2, daysPerWeek: 2, templates: templates) == "ppl-3")
    }

    /// À distance égale, le premier modèle du focus dans l'ordre de la bibliothèque l'emporte.
    @Test func aTieKeepsTheLibraryOrder() {
        func template(_ id: String, strengthDays: Int) -> ProgramTemplate {
            let days = (0..<strengthDays).map { TemplateDay(id: "d\($0)", name: LocalizedText(fr: "J\($0)"), kind: .strength) }
            return ProgramTemplate(id: id, name: LocalizedText(fr: id), summary: LocalizedText(fr: id),
                                   recommendedFor: TemplateRecommendation(focus: .balanced, daysPerWeek: [strengthDays]),
                                   sessionsPerWeek: strengthDays, days: days,
                                   suggestedWeek: days.map(\.id) + [String?](repeating: nil, count: 7 - strengthDays))
        }
        let pair = [template("two", strengthDays: 2), template("four", strengthDays: 4)]
        #expect(TemplateRecommender.recommendedID(focus: 0.5, daysPerWeek: 6, templates: pair) == "two", "3 de musculation")
        #expect(TemplateRecommender.recommendedID(focus: 0.5, daysPerWeek: 6, templates: pair.reversed()) == "four")
    }

    @Test func noTemplateForTheFocusFallsBackToTheFirstTemplate() {
        let strengthOnly = templates.filter { $0.recommendedFor.focus == .strength }
        #expect(TemplateRecommender.recommendedID(focus: 0.9, daysPerWeek: 3, templates: strengthOnly) == "ppl-3")
        #expect(TemplateRecommender.recommendedID(focus: 0.5, daysPerWeek: 3, templates: []) == nil)
    }

    @Test func levelIncrements() {
        #expect(TrainingLevel.advanced.defaultIncrementsKg == (upper: 1.25, lower: 2.5))
        #expect(TrainingLevel.beginner.defaultIncrementsKg == (upper: 2.5, lower: 5))
        #expect(TrainingLevel.intermediate.defaultIncrementsKg == (upper: 2.5, lower: 5))
    }

    @Test func allowedEquipmentByAccess() {
        #expect(EquipmentAccess.fullGym.allowedEquipment == Set(Equipment.allCases))
        #expect(EquipmentAccess.homeGym.allowedEquipment == [.dumbbell, .kettlebell, .band, .bodyweight])
        #expect(EquipmentAccess.bodyweight.allowedEquipment == [.bodyweight])
    }
}
