import Foundation
import os
@testable import PulseDomain
import Testing

private struct Boom: Error {}

@Suite("PulseLog")
struct PulseLogTests {
    private let log = PulseLog.logger("tests")

    @Test("attempt rend la valeur quand rien n'échoue")
    func attemptReturnsValue() {
        #expect(log.attempt("lecture") { 42 } == 42)
    }

    @Test("attempt rend nil après une erreur, comme try?")
    func attemptSwallowsError() {
        let value: Int? = log.attempt("lecture") { throw Boom() }
        #expect(value == nil)
    }

    @Test("le sous-système retombe sur l'identifiant de l'app hors bundle")
    func subsystemFallback() {
        #expect(!PulseLog.subsystem.isEmpty)
        #expect(PulseLog.fallbackSubsystem == "fr.seonay.pulse")
    }
}
