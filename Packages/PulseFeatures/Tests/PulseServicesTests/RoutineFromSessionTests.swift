import Foundation
import PulseContent
import PulseDomain
import PulseServices
import Testing

struct RoutineFromSessionTests {
    private let directory = ExerciseDirectory(library: .bundled, userExercises: [])
    private let bench = ExerciseReference.content(id: "bench-press-barbell")
    private let pecDeck = ExerciseReference.content(id: "pec-deck-machine")
    private let plank = ExerciseReference.content(id: "plank")

    private func set(_ exercise: ExerciseReference, _ type: SetType = .working, reps: Int? = nil, seconds: Int? = nil,
                     superset: Int? = nil) -> WorkoutSet {
        WorkoutSet(order: 0, exercise: exercise, exerciseName: "x", setType: type, supersetGroup: superset,
                   actualWeightKg: 50, actualReps: reps, durationSeconds: seconds)
    }

    private func session(_ sets: [WorkoutSet], title: String = "Push") -> WorkoutSession {
        var numbered = sets
        for index in numbered.indices { numbered[index].order = index }
        return WorkoutSession(startedAt: .t0, kind: .strength, source: .pulse, status: .completed, title: title,
                              sets: numbered, createdAt: .t0, updatedAt: .t0)
    }

    private func day(_ sets: [WorkoutSet], order: Int = 0) -> RoutineDay {
        RoutineFromSession.day(from: session(sets), directory: directory, order: order)
    }

    @Test func routineFromARampingSessionGetsPerSetRanges() {
        let day = day([
            set(bench, .warmup, reps: 10), set(bench, reps: 12), set(bench, reps: 5), set(bench, reps: 5),
            set(pecDeck, reps: 10), set(pecDeck, reps: 8), set(pecDeck, .drop, reps: 9)
        ])
        #expect(day.name == "Push" && day.kind == .strength && day.order == 0)
        #expect(day.exercises.map(\.exercise) == [bench, pecDeck] && day.exercises.map(\.order) == [0, 1])
        #expect(day.exercises[0].sets == 3)
        #expect(day.exercises[0].setTargets == [SetTarget(repsMin: 10, repsMax: 12), SetTarget(repsMin: 4, repsMax: 6),
                                                SetTarget(repsMin: 4, repsMax: 6)])
        #expect(day.exercises[0].repsMin == 4 && day.exercises[0].repsMax == 12)
        #expect(day.exercises[1].sets == 3)
        #expect(day.exercises[1].setTargets == nil)
        #expect(day.exercises[1].repsMin == 6 && day.exercises[1].repsMax == 10)
        #expect(day.exercises.allSatisfy { $0.targetRPE == 8 })
        #expect(day.exercises[0].restSeconds == 120 && day.exercises[1].restSeconds == 60)
    }

    @Test func aSmallSpreadIsWidenedDownToFourRepsApart() {
        #expect(day([set(bench, reps: 8), set(bench, reps: 8)]).exercises[0].repsMin == 4)
        let wide = day([set(bench, reps: 9), set(bench, reps: 12)]).exercises[0]
        #expect(wide.repsMin == 8 && wide.repsMax == 12 && wide.setTargets == nil)
        let floor = day([set(bench, reps: 2), set(bench, reps: 3)]).exercises[0]
        #expect(floor.repsMin == 1 && floor.repsMax == 3)
    }

    @Test func perSetRangesFollowTheTenRepThreshold() {
        let exercise = day([set(bench, reps: 15), set(bench, reps: 10), set(bench, reps: 9), set(bench, reps: 1)]).exercises[0]
        #expect(exercise.setTargets == [SetTarget(repsMin: 13, repsMax: 15), SetTarget(repsMin: 8, repsMax: 10),
                                        SetTarget(repsMin: 8, repsMax: 10), SetTarget(repsMin: 1, repsMax: 2)])
        #expect(exercise.repsMin == 1 && exercise.repsMax == 15)
        #expect(exercise.repRange(forSet: 3) == 1...2)
    }

    @Test func aSpreadOfExactlyThreeStaysOneRange() {
        let exercise = day([set(bench, reps: 6), set(bench, reps: 9)]).exercises[0]
        #expect(exercise.setTargets == nil && exercise.repsMin == 5 && exercise.repsMax == 9)
    }

    @Test func heldExercisesTakeSecondsInsteadOfReps() {
        let exercise = day([set(plank, seconds: 45), set(plank, seconds: 45)]).exercises[0]
        #expect(exercise.sets == 2 && exercise.repsMax == 45 && exercise.repsMin == 41)
        #expect(exercise.restSeconds == 60)
    }

    @Test func exercisesKeepTheirFirstAppearanceOrderAndWarmupOnlyOnesAreDropped() {
        let day = day([set(pecDeck, .warmup, reps: 15), set(bench, reps: 8), set(pecDeck, reps: 10), set(bench, reps: 8)])
        #expect(day.exercises.map(\.exercise) == [bench, pecDeck])
        #expect(day.exercises[0].sets == 2)
        let onlyWarmup = self.day([set(bench, .warmup, reps: 10), set(pecDeck, reps: 10)])
        #expect(onlyWarmup.exercises.map(\.exercise) == [pecDeck])
    }

    @Test func supersetsAreKeptAsConsecutivePairs() {
        let day = day([
            set(bench, reps: 8, superset: 5), set(pecDeck, reps: 10, superset: 5),
            set(bench, reps: 8, superset: 5), set(pecDeck, reps: 10, superset: 5),
            set(plank, seconds: 40)
        ])
        #expect(day.exercises.map(\.supersetGroup) == [1, 1, nil])
    }

    @Test func aSupersetWhoseMembersAreNotNeighboursIsDropped() {
        let day = day([set(bench, reps: 8, superset: 2), set(plank, seconds: 40), set(pecDeck, reps: 10, superset: 2)])
        #expect(day.exercises.map(\.supersetGroup) == [nil, nil, nil])
    }

    @Test func aSessionWithoutRepsFallsBackToTheDefaultRange() {
        let exercise = day([set(bench), set(bench)]).exercises[0]
        #expect(exercise.sets == 2 && exercise.repsMin == 8 && exercise.repsMax == 12 && exercise.setTargets == nil)
    }

    @Test func aSessionOfZeroRepSetsGetsAValidRange() {
        let reps = day([set(bench, reps: 0), set(bench, reps: 0)]).exercises[0]
        #expect(reps.sets == 2 && reps.repsMin == 8 && reps.repsMax == 12 && reps.setTargets == nil)
        let seconds = day([set(plank, seconds: 0)]).exercises[0]
        #expect(seconds.repsMin == 30 && seconds.repsMax == 60)
        let mixed = day([set(bench, reps: 0), set(bench, reps: 6)]).exercises[0]
        #expect(mixed.sets == 2 && mixed.repsMin == 2 && mixed.repsMax == 6 && mixed.setTargets == nil)
        for exercise in [reps, seconds, mixed] {
            for index in 0..<exercise.sets { #expect(exercise.repRange(forSet: index).lowerBound <= exercise.repsMax) }
        }
    }

    @Test func theDayCarriesTheRequestedOrderAndANewIdentity() {
        let first = day([set(bench, reps: 8)], order: 3)
        let second = day([set(bench, reps: 8)], order: 3)
        #expect(first.order == 3 && first.id != second.id)
    }
}
