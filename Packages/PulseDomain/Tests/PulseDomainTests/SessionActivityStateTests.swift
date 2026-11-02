import Foundation
@testable import PulseDomain
import Testing

private let sessionID = UUID(uuidString: "00000000-0000-0000-0000-000000000042") ?? UUID()

private func makeState(title: String = "Push A", restEndsAt: Date? = nil) -> SessionActivityState {
    SessionActivityState(
        sessionID: sessionID,
        title: title,
        startedAt: Date(timeIntervalSince1970: 1_000),
        restStartedAt: restEndsAt.map { $0.addingTimeInterval(-90) },
        restEndsAt: restEndsAt,
        nextSet: "Développé couché · 70 kg × 5"
    )
}

@Suite("SessionActivityState et doublures")
struct SessionActivityStateTests {
    @Test("l'état d'activité survit à un aller-retour Codable")
    func codableRoundTrip() throws {
        let state = makeState(restEndsAt: Date(timeIntervalSince1970: 2_000))
        let data = try JSONEncoder().encode(state)
        #expect(try JSONDecoder().decode(SessionActivityState.self, from: data) == state)
    }

    @Test("l'état sans repos ni prochaine série survit à un aller-retour Codable")
    func codableRoundTripWithoutOptionals() throws {
        var state = makeState()
        state.nextSet = nil
        let data = try JSONEncoder().encode(state)
        #expect(try JSONDecoder().decode(SessionActivityState.self, from: data) == state)
    }

    @Test("le notificateur de repos garde les planifications dans l'ordre et compte les annulations")
    func restNotifierRecords() async {
        let notifier = StubRestTimerNotifier()
        let first = Date(timeIntervalSince1970: 100)
        let second = Date(timeIntervalSince1970: 200)
        await notifier.scheduleRestEnd(at: first, message: RestEndMessage(title: "Repos terminé", body: "Série 2"))
        await notifier.scheduleRestEnd(at: second, message: RestEndMessage(title: "Repos terminé", body: "Série 3"))
        await notifier.cancelRestEnd()
        let scheduled = await notifier.scheduled
        #expect(scheduled.map(\.date) == [first, second])
        #expect(scheduled.map(\.message.body) == ["Série 2", "Série 3"])
        #expect(await notifier.cancelCount == 1)
    }

    @Test("le contrôleur d'activité garde démarrages, mises à jour et fins dans l'ordre")
    func activityControllerRecords() async {
        let controller = StubSessionActivityController()
        let started = makeState()
        let resting = makeState(restEndsAt: Date(timeIntervalSince1970: 2_000))
        await controller.start(started)
        await controller.update(resting)
        await controller.end()
        await controller.endAll(except: sessionID)
        await controller.endAll(except: nil)
        #expect(await controller.states == [started, resting])
        #expect(await controller.endCount == 1)
        #expect(await controller.endAllCalls == [sessionID, nil])
    }
}
