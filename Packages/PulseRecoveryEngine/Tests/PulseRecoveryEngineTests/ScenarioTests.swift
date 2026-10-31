import Foundation
import PulseDomain
@testable import PulseRecoveryEngine
import Testing

@Suite struct ScenarioTests {
    @Test(arguments: ["bonne-nuit", "mauvaise-nuit", "vfc-manquante", "huit-nuits", "trois-nuits", "sans-donnees"])
    func scenarioMatchesExpectation(name: String) throws {
        let scenario = try RecoveryScenario.load(named: "scenario-\(name)", from: .module)
        let outcome = RecoveryCalculator(calendar: TestCalendar.paris)
            .compute(day: scenario.day, today: scenario.today, history: scenario.history)
        switch (scenario.expected.outcome, outcome) {
        case ("measured", .measured(let r)):
            #expect(r.category == scenario.expected.category)
            #expect(abs(r.score - (scenario.expected.score ?? .nan)) < 1e-6)
            #expect(r.missing == scenario.expected.missing)
            #expect(describe(r.calibration) == scenario.expected.calibration)
        case ("needsCheckIn", .needsCheckIn(let missing)):
            #expect(missing == scenario.expected.missing)
        default:
            Issue.record("outcome inattendu pour \(name): \(outcome)")
        }
    }

    @Test func scenarioDatesDecodeAtParisMidnight() throws {
        let scenario = try RecoveryScenario.load(named: "scenario-bonne-nuit", from: .module)
        #expect(scenario.day == TestCalendar.day(2026, 11, 20))
        #expect(scenario.history.first?.day == TestCalendar.day(2026, 11, 6))
        #expect(scenario.history.count == 14)
    }

    private func describe(_ state: CalibrationState) -> String {
        switch state {
        case .ready: "ready"
        case .calibrating(let nights): "calibrating:\(nights)"
        }
    }
}
