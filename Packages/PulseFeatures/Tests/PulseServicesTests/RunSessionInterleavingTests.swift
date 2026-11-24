import Foundation
import PulseDomain
import Testing

@testable import PulseServices

/// Le brouillon tenu à jour sans point, et les effets d'un point qui attendent pendant une pause ou une reprise.
@Suite(.timeLimit(.minutes(1)))
struct RunSessionInterleavingTests {
    @Test func locationDeniedInterruptedRunKeepsItsDuration() async throws {
        let fixture = RunSessionFixture(location: StubRunLocationTracker(state: .denied))
        let snapshot = try await fixture.service.start(.free())
        for _ in 0..<30 { await fixture.tick(after: 10) }
        let draft = try #require(try await fixture.drafts.load())
        #expect(draft.updatedAt == fixture.start.addingTimeInterval(300))

        // Le processus meurt ; au lancement suivant, la séance HealthKit n'est pas récupérée.
        let relaunched = fixture.relaunched()
        let offer = try #require(await relaunched.recoveryOffer())
        #expect(!offer.isStillRecording)
        #expect(offer.lastPointAt == fixture.start.addingTimeInterval(300))
        let recap = try await relaunched.saveInterrupted()
        #expect(recap.session.id == snapshot.sessionID)
        #expect(abs((recap.session.durationMinutes ?? 0) - 5) < 0.01)
        #expect(recap.session.distanceMeters == nil)
    }

    @Test func pausedRunKeepsItsDraftStill() async throws {
        let fixture = RunSessionFixture(location: StubRunLocationTracker(state: .denied))
        _ = try await fixture.service.start(.free())
        await fixture.tick(after: 10)
        await fixture.service.pause()
        let writes = await fixture.drafts.saveCount
        for _ in 0..<6 { await fixture.tick(after: 10) }
        #expect(await fixture.drafts.saveCount == writes)
    }

    /// Un point dont les effets (rappel, Live Activity) attendent pendant qu'une pause se termine : ils ne la défont pas.
    @Test func staleEffectsDoNotUndoAPause() async throws {
        let fixture = RunSessionFixture()
        _ = try await fixture.service.start(.free())
        let start = fixture.start
        await fixture.push([RunTraceFactory.point(northMeters: 0, second: 1, start: start)])
        let gate = Gate()
        await fixture.drafts.holdNextSave(at: gate)
        // 70 s plus tard, 100 m plus loin : brouillon, Live Activity et rappel sont dus au même point.
        let moved = RunTraceFactory.point(northMeters: 100, second: 70, start: start)
        fixture.clock.set(date: moved.timestamp)
        await fixture.location.push(moved)
        await gate.waitForArrival()

        await fixture.service.pause()
        await gate.open()
        await fixture.service.waitUntilHandled(points: 2)

        let calls = await fixture.reminders.calls
        let cancel = try #require(calls.lastIndex(of: .cancel))
        #expect(calls.suffix(from: cancel).count == 1)
        #expect(await fixture.activity.states.last?.isPaused == true)
        #expect(await fixture.service.current()?.isPaused == true)
    }

    /// L'inverse : les effets d'un point reçu en pause ne défont pas la reprise qui s'est terminée pendant leur attente.
    @Test func staleEffectsDoNotUndoAResume() async throws {
        let fixture = RunSessionFixture()
        _ = try await fixture.service.start(.free())
        let start = fixture.start
        await fixture.push([RunTraceFactory.point(northMeters: 0, second: 1, start: start)])
        await fixture.service.pause()
        let gate = Gate()
        await fixture.drafts.holdNextSave(at: gate)
        let still = RunTraceFactory.point(northMeters: 0, second: 70, start: start)
        fixture.clock.set(date: still.timestamp)
        await fixture.location.push(still)
        await gate.waitForArrival()

        await fixture.service.resume()
        await gate.open()
        await fixture.service.waitUntilHandled(points: 2)

        let resumedAt = still.timestamp
        #expect(await fixture.reminders.calls.last == .schedule(resumedAt.addingTimeInterval(RunSessionService.forgottenAfter)))
        #expect(await fixture.activity.states.last?.isPaused == false)
    }
}
