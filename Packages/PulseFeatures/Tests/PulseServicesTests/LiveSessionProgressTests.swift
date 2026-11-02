import Foundation
import PulseDomain
import PulseRecoveryEngine
import PulseServices
import Testing

struct LiveSessionProgressTests {
    private typealias Fix = LiveFixtures

    private func supersetSession() -> LiveSession {
        let day = Fix.day([
            Fix.exercise(Fix.bench, order: 0, sets: 3, superset: 1),
            Fix.exercise(Fix.pecDeck, order: 1, sets: 3, superset: 1),
            Fix.exercise(Fix.plank, order: 2, sets: 2, reps: 30...60)
        ])
        return Fix.session(Fix.launch(day, nil))
    }

    private func validate(_ session: inout LiveSession, _ exercise: Int, _ set: Int) {
        session.exercises[exercise].sets[set].completedAt = .t1
    }

    @Test func supersetOrderAlternatesTheTwoExercises() throws {
        var session = supersetSession()
        let expected = [(0, 0), (1, 0), (0, 1), (1, 1), (0, 2), (1, 2), (2, 0), (2, 1)]
        for (exercise, set) in expected {
            let next = try #require(session.nextSet)
            #expect(next.exerciseIndex == exercise && next.setIndex == set)
            validate(&session, exercise, set)
        }
        #expect(session.nextSet == nil)
    }

    @Test func nextSetFollowsWhatIsStillToDoWhenSetsAreSkipped() throws {
        var session = supersetSession()
        validate(&session, 0, 0)
        validate(&session, 0, 1)
        let next = try #require(session.nextSet)
        #expect(next.exerciseIndex == 1 && next.setIndex == 0)
    }

    @Test func aSessionWithoutExercisesHasNoNextSet() {
        let session = Fix.session(.free(policy: ProgressionPolicy(allowsIncrease: true)))
        #expect(session.nextSet == nil && session.plannedWorkingSets == 0 && session.doneWorkingSets == 0)
        #expect(session.tonnageKg == 0)
    }

    @Test func countsAndTonnageOnlyUseValidatedWorkingSets() {
        let day = Fix.day([Fix.exercise(Fix.bench, order: 0), Fix.exercise(Fix.pullUp, order: 1, sets: 2),
                          Fix.exercise(Fix.assistedPullUp, order: 2, sets: 1)])
        var session = Fix.session(Fix.launch(day, nil), history: [
            Fix.bench: [Fix.done(Fix.bench, 60, 10)], Fix.pullUp: [Fix.done(Fix.pullUp, 10, 8)],
            Fix.assistedPullUp: [Fix.done(Fix.assistedPullUp, 20, 8)]
        ])
        #expect(session.plannedWorkingSets == 6 && session.doneWorkingSets == 0 && session.tonnageKg == 0)
        // Bench 60 × 10 validée telle que proposée (reps 10 car 12 n'est pas atteint : 10 → 11 visé).
        session.exercises[0].sets[0].completedAt = .t1
        session.exercises[0].sets[0].weightKg = 60
        session.exercises[0].sets[0].reps = 10
        // Tractions lestées 10 × 8, assistée : ne compte pas dans le tonnage.
        session.exercises[1].sets[0].completedAt = .t1
        session.exercises[1].sets[0].weightKg = 10
        session.exercises[1].sets[0].reps = 8
        session.exercises[2].sets[0].completedAt = .t1
        session.exercises[2].sets[0].weightKg = 20
        session.exercises[2].sets[0].reps = 8
        // Non validée : ignorée.
        session.exercises[0].sets[1].weightKg = 100
        session.exercises[0].sets[1].reps = 10
        #expect(session.doneWorkingSets == 3)
        #expect(session.tonnageKg == 600 + 80)
    }

    @Test func warmUpSetsAreNotWorkingSets() {
        var session = Fix.session(Fix.launch(Fix.day([Fix.exercise(Fix.bench, sets: 2)]), nil))
        session.exercises[0].sets[0].setType = .warmup
        session.exercises[0].sets[0].completedAt = .t1
        session.exercises[0].sets[0].weightKg = 40
        session.exercises[0].sets[0].reps = 10
        #expect(session.plannedWorkingSets == 1 && session.doneWorkingSets == 0 && session.tonnageKg == 0)
        // La série d'échauffement validée n'est plus à faire.
        #expect(session.nextSet?.setIndex == 1)
    }
}
