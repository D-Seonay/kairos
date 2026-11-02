import Foundation
import PulseDomain
import PulseServices
import Testing

struct RoutineRulesTests {
    private func exercise(sets: Int = 3, reps: ClosedRange<Int> = 8...12, rpe: Double = 8, rest: Int = 90,
                          setTargets: [SetTarget]? = nil) -> RoutineExercise {
        RoutineExercise(order: 0, exercise: .content(id: "bench-press-barbell"), sets: sets, repsMin: reps.lowerBound,
                        repsMax: reps.upperBound, targetRPE: rpe, restSeconds: rest, setTargets: setTargets)
    }

    @Test func rangesMatchTheSpec() {
        #expect(RoutineRules.sets == 1...10 && RoutineRules.reps == 1...30 && RoutineRules.seconds == 5...600)
        #expect(RoutineRules.rpe == 6.0...10.0 && RoutineRules.rest == 0...300)
        #expect(RoutineRules.rpeStep == 0.5 && RoutineRules.restStep == 15)
    }

    @Test func aDefaultExerciseHasNoIssue() {
        #expect(RoutineRules.issues(in: exercise(), tracksDuration: false).isEmpty)
        #expect(RoutineRules.issues(in: exercise(reps: 30...60), tracksDuration: true).isEmpty)
        #expect(RoutineRules.issues(in: exercise(sets: 10, reps: 1...30, rpe: 6, rest: 0), tracksDuration: false).isEmpty)
        #expect(RoutineRules.issues(in: exercise(rpe: 10, rest: 300), tracksDuration: false).isEmpty)
    }

    @Test func rulesRejectOutOfRangeValues() {
        let targets = [SetTarget(repsMin: 8, repsMax: 12), SetTarget(repsMin: 8, repsMax: 12)]
        let bad = exercise(sets: 11, rpe: 10.5, rest: 310, setTargets: targets)
        #expect(RoutineRules.issues(in: bad, tracksDuration: false) == [.sets, .rpe, .rest, .setTargets])
    }

    @Test func repsFollowTheUnitOfTheExercise() {
        #expect(RoutineRules.issues(in: exercise(reps: 8...31), tracksDuration: false) == [.reps])
        #expect(RoutineRules.issues(in: exercise(reps: 0...12), tracksDuration: false) == [.reps])
        #expect(RoutineRules.issues(in: exercise(reps: 30...60), tracksDuration: false) == [.reps])
        #expect(RoutineRules.issues(in: exercise(reps: 4...60), tracksDuration: true) == [.reps])
        #expect(RoutineRules.issues(in: exercise(reps: 30...601), tracksDuration: true) == [.reps])
    }

    @Test func invertedRangesAreReportedWithoutTrapping() {
        var inverted = exercise()
        inverted.repsMin = 12
        inverted.repsMax = 8
        #expect(RoutineRules.issues(in: inverted, tracksDuration: false) == [.reps])
        inverted.repsMin = 8
        inverted.repsMax = 12
        inverted.setTargets = [SetTarget(repsMin: 8, repsMax: 12), SetTarget(repsMin: 10, repsMax: 6), SetTarget(repsMin: 8, repsMax: 12)]
        #expect(RoutineRules.issues(in: inverted, tracksDuration: false) == [.setTargets])
    }

    @Test func rpeAndRestMustFollowTheirSteps() {
        #expect(RoutineRules.issues(in: exercise(rpe: 8.25), tracksDuration: false) == [.rpe])
        #expect(RoutineRules.issues(in: exercise(rpe: 5.5), tracksDuration: false) == [.rpe])
        #expect(RoutineRules.issues(in: exercise(rpe: 8.5), tracksDuration: false).isEmpty)
        #expect(RoutineRules.issues(in: exercise(rest: 100), tracksDuration: false) == [.rest])
        #expect(RoutineRules.issues(in: exercise(rest: -15), tracksDuration: false) == [.rest])
    }

    @Test func setTargetsMustMatchTheSetCount() {
        let three = Array(repeating: SetTarget(repsMin: 8, repsMax: 12), count: 3)
        #expect(RoutineRules.issues(in: exercise(setTargets: three), tracksDuration: false).isEmpty)
        #expect(RoutineRules.issues(in: exercise(sets: 4, setTargets: three), tracksDuration: false) == [.setTargets])
    }
}
