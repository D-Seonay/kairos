import Foundation
import PulseDomain
import Testing

@testable import PulseServices

/// La surveillance de l'oubli n'a de sens qu'avec des points retenus.
@Suite(.timeLimit(.minutes(1)))
struct RunForgottenReminderTests {
    /// Positions toutes trop imprécises (position approximative) : ni rappel ni alerte d'oubli, qui proposerait de terminer au
    /// départ pendant que l'on court. Le premier point retenu ouvre la surveillance, à partir de lui.
    @Test func noForgottenReminderWithoutAKeptPoint() async throws {
        let fixture = RunSessionFixture()
        _ = try await fixture.service.start(.free())
        #expect(await fixture.reminders.scheduled.isEmpty)
        let blurred = (1...130).map { step in
            RunTraceFactory.point(northMeters: Double(step) * 40, second: step * 15, start: fixture.start, accuracy: 1_500)
        }
        await fixture.push(blurred)
        #expect(await fixture.reminders.scheduled.isEmpty)
        #expect(await fixture.service.forgottenEnd() == nil)

        let fixAt = fixture.clock.now.addingTimeInterval(1)
        let fix = RunTraceFactory.point(northMeters: 0, second: Int(fixAt.timeIntervalSince(fixture.start)), start: fixture.start)
        await fixture.push([fix])
        #expect(await fixture.reminders.scheduled == [fixAt.addingTimeInterval(RunSessionService.forgottenAfter)])
        fixture.advance(minutes: 31)
        #expect(await fixture.service.forgottenEnd() == fixAt)
    }
}
