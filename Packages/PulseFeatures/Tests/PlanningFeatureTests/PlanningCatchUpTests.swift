import Foundation
import PlanningFeature
import PulseDomain
import PulseServices
import Testing

@MainActor
struct PlanningCatchUpTests {
    @Test func aMissedDayIsCaughtUpOnARestDay() async throws {
        let fixture = PlanningFixture()
        try await fixture.activate()
        let model = PlanningModel(environment: fixture.environment)
        await model.load()

        let pull = model.days[1]
        #expect(model.canCatchUp(pull) && !model.canCatchUp(model.days[2]))
        let targets = model.catchUpTargets(for: pull)
        #expect(targets.map { model.catchUpLabel(of: $0) }
            == ["Samedi · Repos (conseillé)", "Mercredi · remplace Legs", "Jeudi · remplace Endurance", "Vendredi · remplace Push"])

        await model.catchUp(pull, on: targets[0])
        #expect(model.days[1].state == .caughtUp && model.catchingUp == nil)
        #expect(model.detail(of: model.days[1]) == "Rattrapée samedi")
        #expect(model.days[5].routine?.name == "Pull")
        #expect(model.detail(of: model.days[5]) == "Rattrapage de mardi")
        #expect(!model.canCatchUp(model.days[1]))
    }
}
