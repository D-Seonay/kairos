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

    /// Une séance enregistrée avant M8 n'a pas les textes parlés : elle se relit, sans eux.
    @Test func aSnapshotSavedBeforeTheSpokenTextsStillDecodes() throws {
        let session = session()
        #expect(session.exercises[0].lastTimeSpoken != nil && session.exercises[0].sets.contains { $0.previousSpoken != nil })
        var json = try #require(try JSONSerialization.jsonObject(with: session.encoded()) as? [String: Any])
        var exercises = try #require(json["exercises"] as? [[String: Any]])
        for index in exercises.indices {
            exercises[index]["lastTimeSpoken"] = nil
            var sets = try #require(exercises[index]["sets"] as? [[String: Any]])
            for setIndex in sets.indices { sets[setIndex]["previousSpoken"] = nil }
            exercises[index]["sets"] = sets
        }
        json["exercises"] = exercises
        let old = try JSONSerialization.data(withJSONObject: json)
        #expect(String(bytes: old, encoding: .utf8)?.contains("Spoken") == false)

        var expected = session
        for index in expected.exercises.indices {
            expected.exercises[index].lastTimeSpoken = nil
            for setIndex in expected.exercises[index].sets.indices {
                expected.exercises[index].sets[setIndex].previousSpoken = nil
            }
        }
        #expect(LiveSession.decode(old) == expected)
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
