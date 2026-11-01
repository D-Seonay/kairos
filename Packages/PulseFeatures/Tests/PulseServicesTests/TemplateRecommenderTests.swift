import PulseContent
import PulseDomain
import PulseServices
import Testing

struct TemplateRecommenderTests {
    private let templates = ContentLibrary.bundled.programTemplates

    @Test func recommendations() {
        #expect(TemplateRecommender.recommendedID(focus: 0.2, daysPerWeek: 3, templates: templates) == "ppl-3")
        #expect(TemplateRecommender.recommendedID(focus: 0.2, daysPerWeek: 6, templates: templates) == "ppl-6")
        #expect(TemplateRecommender.recommendedID(focus: 0.5, daysPerWeek: 4, templates: templates) == "upper-lower")
        #expect(TemplateRecommender.recommendedID(focus: 0.9, daysPerWeek: 3, templates: templates) == "runner-strength")
    }

    @Test func focusThresholdsAreExclusive() {
        #expect(TemplateRecommender.focus(for: 0.34) == .strength)
        #expect(TemplateRecommender.focus(for: 0.35) == .balanced)
        #expect(TemplateRecommender.focus(for: 0.65) == .balanced)
        #expect(TemplateRecommender.focus(for: 0.66) == .endurance)
    }

    @Test func closestDayCountWinsWhenNoTemplateMatches() {
        #expect(TemplateRecommender.recommendedID(focus: 0.2, daysPerWeek: 5, templates: templates) == "ppl-6")
        #expect(TemplateRecommender.recommendedID(focus: 0.2, daysPerWeek: 2, templates: templates) == "ppl-3")
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
