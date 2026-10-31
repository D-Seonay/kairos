import Foundation
import PulseDomain
import Testing
@testable import PulseRecoveryEngine

@Suite struct ScenarioTests {
    @Test(arguments: ["bonne-nuit", "mauvaise-nuit", "vfc-manquante", "huit-nuits", "trois-nuits", "sans-donnees"])
    func scenarioMatchesExpectation(name: String) throws {
        let s = try RecoveryScenario.load(named: "scenario-\(name)", from: .module)
        let outcome = RecoveryCalculator(calendar: TestCalendar.paris).compute(day: s.day, today: s.today, history: s.history)
        switch (s.expected.outcome, outcome) {
        case ("measured", .measured(let r)):
            #expect(r.category == s.expected.category)
            #expect(abs(r.score - (s.expected.score ?? .nan)) < 1e-6)
            #expect(r.missing == s.expected.missing)
            #expect(describe(r.calibration) == s.expected.calibration)
        case ("needsCheckIn", .needsCheckIn(let missing)):
            #expect(missing == s.expected.missing)
        default:
            Issue.record("outcome inattendu pour \(name): \(outcome)")
        }
    }

    @Test func scenarioDatesDecodeAtParisMidnight() throws {
        let s = try RecoveryScenario.load(named: "scenario-bonne-nuit", from: .module)
        #expect(s.day == TestCalendar.day(2026, 11, 20))
        #expect(s.history.first?.day == TestCalendar.day(2026, 11, 6))
        #expect(s.history.count == 14)
    }

    private func describe(_ state: CalibrationState) -> String {
        switch state {
        case .ready: "ready"
        case .calibrating(let nights): "calibrating:\(nights)"
        }
    }
}
