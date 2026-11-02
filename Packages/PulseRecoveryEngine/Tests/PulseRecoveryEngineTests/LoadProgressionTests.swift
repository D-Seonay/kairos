import Foundation
import PulseDomain
@testable import PulseRecoveryEngine
import Testing

struct LoadProgressionTests {
    private let bar = WeightRounding.plates(barKg: 20, smallestPlateKg: 1.25)

    private func routine(sets: Int, range: ClosedRange<Int> = 8...12, targets: [ClosedRange<Int>]? = nil) -> RoutineExercise {
        RoutineExercise(order: 0, exercise: .content(id: "exercise"), sets: sets, repsMin: range.lowerBound, repsMax: range.upperBound,
                        targetRPE: 8, restSeconds: 90,
                        setTargets: targets?.map { SetTarget(repsMin: $0.lowerBound, repsMax: $0.upperBound) })
    }

    private func done(_ weight: Double?, _ reps: Int?, rpe: Double? = nil, seconds: Int? = nil) -> WorkoutSet {
        WorkoutSet(order: 0, exercise: .content(id: "exercise"), exerciseName: "Exercice", setType: .working,
                   actualWeightKg: weight, actualReps: reps, durationSeconds: seconds, rpe: rpe)
    }

    private func propose(_ exercise: RoutineExercise, last: [WorkoutSet], kind: LoadKind = .external, timed: Bool = false,
                         increment: Double = 2.5, rounding: WeightRounding? = nil,
                         policy: ProgressionPolicy = .open) -> ExerciseProposal {
        LoadProgression.propose(exercise: exercise, name: "Développé couché à la barre", loadKind: kind, tracksDuration: timed,
                                lastSets: last, incrementKg: increment, rounding: rounding ?? bar, policy: policy)
    }

    private func reason(_ change: String, sets: String, reached: String) -> String {
        "Développé couché à la barre : \(change) \(sets), \(reached) atteintes la dernière fois"
    }

    private var rampingBench: RoutineExercise { routine(sets: 3, range: 4...12, targets: [10...12, 4...6, 4...6]) }
    private var rampingLast: [WorkoutSet] { [done(60, 12, rpe: 7.5), done(70, 6), done(70, 5)] }

    @Test func rampingBenchProgressesSetBySet() {
        let proposal = propose(rampingBench, last: rampingLast)
        #expect(proposal.sets.map(\.weightKg) == [62.5, 72.5, 70])
        #expect(proposal.sets.map(\.reps) == [10, 4, 6])
        #expect(proposal.sets.map(\.isIncrease) == [true, true, false])
        #expect(proposal.loadAdjustment?.kind == .load)
        #expect(proposal.loadAdjustment?.value == 2.5)
        let expected = "Développé couché à la barre : +2,5 kg sur 2 séries, 12 répétitions atteintes la dernière fois"
        #expect(proposal.loadAdjustment?.reason == expected)
    }

    @Test func aSingleIncreasedSetSaysSet() {
        let proposal = propose(routine(sets: 2), last: [done(60, 12), done(60, 10)])
        #expect(proposal.sets.map(\.isIncrease) == [true, false])
        #expect(proposal.loadAdjustment?.reason == reason("+2,5 kg", sets: "sur 1 série", reached: "12 répétitions"))
    }

    @Test func aHighRPEBlocksTheIncrease() {
        let proposal = propose(routine(sets: 1), last: [done(60, 12, rpe: 9)])
        #expect(proposal.sets.map(\.weightKg) == [60])
        #expect(proposal.sets.map(\.reps) == [12])
        #expect(proposal.sets.map(\.isIncrease) == [false])
        #expect(proposal.loadAdjustment == nil)
    }

    @Test func anRPEOfEightStillAllowsTheIncrease() {
        let proposal = propose(routine(sets: 1), last: [done(60, 12, rpe: 8)])
        #expect(proposal.sets.map(\.weightKg) == [62.5])
    }

    @Test func aClosedPolicyKeepsLastTimeExactly() {
        let proposal = propose(rampingBench, last: rampingLast, policy: .closed)
        #expect(proposal.sets.map(\.weightKg) == [60, 70, 70])
        #expect(proposal.sets.map(\.reps) == [12, 6, 5])
        #expect(proposal.sets.map(\.isIncrease) == [false, false, false])
        #expect(proposal.loadAdjustment == nil)
    }

    @Test func noHistoryProposesTheBottomOfEachRange() {
        let proposal = propose(rampingBench, last: [])
        #expect(proposal.sets.map(\.weightKg) == [nil, nil, nil])
        #expect(proposal.sets.map(\.reps) == [10, 4, 4])
        #expect(proposal.sets.map(\.isIncrease) == [false, false, false])
        #expect(proposal.loadAdjustment == nil)
    }

    @Test func moreSetsThanLastTimeRepeatTheLastOne() {
        let proposal = propose(routine(sets: 4), last: [done(60, 9), done(60, 8)])
        #expect(proposal.sets.map(\.weightKg) == [60, 60, 60, 60])
        #expect(proposal.sets.map(\.reps) == [10, 9, 9, 9])
    }

    @Test func fewerSetsThanLastTimeDropTheExtraOnes() {
        let proposal = propose(routine(sets: 1), last: [done(60, 9), done(60, 8)])
        #expect(proposal.sets.count == 1)
    }

    @Test func repsClimbOneByOneWithoutPassingTheTop() {
        #expect(propose(routine(sets: 1), last: [done(60, 11)]).sets.map(\.reps) == [12])
        #expect(propose(routine(sets: 1), last: [done(60, 8)]).sets.map(\.reps) == [9])
    }

    @Test func cableStackUsesTheMachineIncrement() {
        let proposal = propose(routine(sets: 1, range: 10...15), last: [done(27, 15)], increment: 3.5, rounding: .increment)
        #expect(proposal.sets.map(\.weightKg) == [30.5])
        #expect(proposal.sets.map(\.reps) == [10])
        #expect(proposal.loadAdjustment?.value == 3.5)
    }

    @Test func bodyweightAddsWeightFromZero() {
        let exercise = routine(sets: 2, range: 8...12)
        let proposal = propose(exercise, last: [done(nil, 12), done(5, 12)], kind: .bodyweight)
        #expect(proposal.sets.map(\.weightKg) == [2.5, 7.5])
        #expect(proposal.sets.map(\.reps) == [8, 8])
        #expect(proposal.sets.map(\.isIncrease) == [true, true])
        #expect(proposal.loadAdjustment?.value == 2.5)
    }

    @Test func assistedDipsLowerTheAssistanceThenAskForMoreReps() {
        let exercise = routine(sets: 2, range: 8...12)
        let lowering = propose(exercise, last: [done(10, 12), done(1, 12)], kind: .assisted)
        #expect(lowering.sets.map(\.weightKg) == [7.5, 0])
        #expect(lowering.sets.map(\.reps) == [8, 8])
        #expect(lowering.sets.map(\.isIncrease) == [true, true])
        #expect(lowering.loadAdjustment?.value == -2.5)
        #expect(lowering.loadAdjustment?.reason == reason("assistance −2,5 kg", sets: "sur 2 séries", reached: "12 répétitions"))

        let bodyweight = propose(exercise, last: [done(0, 12), done(0, 10)], kind: .assisted)
        #expect(bodyweight.sets.map(\.weightKg) == [0, 0])
        #expect(bodyweight.sets.map(\.reps) == [13, 11])
        #expect(bodyweight.sets.map(\.isIncrease) == [false, false])
        #expect(bodyweight.loadAdjustment?.value == 0)
        #expect(bodyweight.loadAdjustment?.reason.contains("poids du corps") == true)
    }

    @Test func anEmptyAssistanceCountsAsZero() {
        let proposal = propose(routine(sets: 1), last: [done(nil, 9)], kind: .assisted)
        #expect(proposal.sets.map(\.weightKg) == [0])
        #expect(proposal.sets.map(\.reps) == [10])
    }

    @Test func timedHoldsProposeSeconds() {
        let exercise = routine(sets: 2, range: 30...60)
        let proposal = propose(exercise, last: [done(nil, nil, seconds: 60), done(nil, nil, seconds: 45)], kind: .bodyweight, timed: true)
        #expect(proposal.sets.map(\.durationSeconds) == [30, 46])
        #expect(proposal.sets.map(\.reps) == [nil, nil])
        #expect(proposal.sets.map(\.weightKg) == [2.5, nil])
        #expect(proposal.loadAdjustment?.reason == reason("+2,5 kg", sets: "sur 1 série", reached: "60 secondes"))
    }

    @Test func timedHoldsWithoutHistoryProposeTheBottomSeconds() {
        let proposal = propose(routine(sets: 2, range: 30...60), last: [], kind: .bodyweight, timed: true)
        #expect(proposal.sets.map(\.durationSeconds) == [30, 30])
        #expect(proposal.sets.map(\.reps) == [nil, nil])
    }

    @Test func aReferenceWithoutRepsCountsAsNoHistory() {
        let proposal = propose(routine(sets: 1), last: [done(60, nil)])
        #expect(proposal.sets.map(\.weightKg) == [nil])
        #expect(proposal.sets.map(\.reps) == [8])
    }

    @Test func aRangeEnteredBackwardsDoesNotTrap() {
        let exercise = routine(sets: 1, range: 12...12, targets: nil)
        var inverted = exercise
        inverted.repsMin = 12
        inverted.repsMax = 8
        let proposal = propose(inverted, last: [done(60, 12)])
        #expect(proposal.sets.map(\.weightKg) == [62.5])
        #expect(proposal.sets.map(\.reps) == [8])
    }

    @Test func formatsFractionalIncrementsTheFrenchWay() {
        let proposal = propose(routine(sets: 1), last: [done(60, 12)], increment: 1.25)
        #expect(proposal.loadAdjustment?.reason == reason("+2,5 kg", sets: "sur 1 série", reached: "12 répétitions"))
        let machine = propose(routine(sets: 1), last: [done(27, 12)], increment: 1.25, rounding: .increment)
        #expect(machine.loadAdjustment?.reason == reason("+1,25 kg", sets: "sur 1 série", reached: "12 répétitions"))
        let whole = propose(routine(sets: 1), last: [done(27, 12)], increment: 5, rounding: .increment)
        #expect(whole.loadAdjustment?.reason == reason("+5 kg", sets: "sur 1 série", reached: "12 répétitions"))
    }
}
