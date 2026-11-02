import Foundation
import PulseDomain
import PulseServices
import Testing

struct LiveSessionCodingTests {
    private typealias Fix = LiveFixtures

    private func session() -> LiveSession {
        let day = Fix.day([Fix.exercise(Fix.bench, order: 0), Fix.exercise(Fix.plank, order: 1, sets: 1, reps: 30...60)])
        var session = Fix.session(Fix.launch(day, .normal), history: [Fix.bench: Fix.rampingBench])
        session.exercises[0].sets[0].completedAt = .t1
        session.exercises[0].sets[0].weightKg = 65
        session.exercises[0].sets[0].isEdited = true
        session.exercises[0].sets[0].rpe = 8.5
        session.rest = LiveRest(startedAt: .t1, endsAt: .t2, exerciseID: session.exercises[0].id)
        return session
    }

    @Test func aSnapshotRoundTripsAndRejectsAnUnknownFormat() throws {
        let session = session()
        let data = try session.encoded()
        #expect(try JSONDecoder().decode(LiveSession.self, from: data) == session)
        #expect(LiveSession.decode(data) == session)

        var future = session
        future.formatVersion = 99
        #expect(LiveSession.decode(try future.encoded()) == nil)
    }

    @Test func anUnreadableSnapshotIsNil() throws {
        #expect(LiveSession.decode(Data("pas du JSON".utf8)) == nil)
        #expect(LiveSession.decode(Data("{}".utf8)) == nil)
        #expect(LiveSession.decode(Data()) == nil)
        // Format connu mais contenu tronqué.
        #expect(LiveSession.decode(Data("{\"formatVersion\":1}".utf8)) == nil)
    }

    @Test func aFutureFormatIsRejectedEvenWhenItsShapeChanged() {
        #expect(LiveSession.decode(Data("{\"formatVersion\":2,\"exercises\":\"autre chose\"}".utf8)) == nil)
    }

    @Test func theCurrentFormatIsOne() {
        #expect(LiveSession.currentFormat == 1 && session().formatVersion == 1)
    }
}
