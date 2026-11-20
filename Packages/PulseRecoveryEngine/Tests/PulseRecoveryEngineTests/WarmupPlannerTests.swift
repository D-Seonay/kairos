@testable import PulseRecoveryEngine
import Testing

struct WarmupPlannerTests {
    private let bar = WeightRounding.plates(barKg: 20, smallestPlateKg: 1.25)

    @Test func aBarbellLiftGetsTheBarThenSixtyAndEightyPercent() {
        let sets = WarmupPlanner.sets(firstWorkingKg: 100, rounding: bar, incrementKg: 2.5, maxCount: nil)
        #expect(sets == [WarmupSet(weightKg: 20, reps: 10), WarmupSet(weightKg: 60, reps: 5), WarmupSet(weightKg: 80, reps: 3)])
    }

    @Test func otherEquipmentGetsSixtyAndEightyPercentRoundedDownToTheIncrement() {
        let sets = WarmupPlanner.sets(firstWorkingKg: 47, rounding: .increment, incrementKg: 2.5, maxCount: nil)
        #expect(sets == [WarmupSet(weightKg: 27.5, reps: 5), WarmupSet(weightKg: 37.5, reps: 3)])
    }

    @Test func percentagesRoundDownToAPairOfPlates() {
        let sets = WarmupPlanner.sets(firstWorkingKg: 62.5, rounding: bar, incrementKg: 2.5, maxCount: nil)
        // 60 % = 37,5 (20 + 2 × 8,75 → 7 paires de 1,25) ; 80 % = 50.
        #expect(sets.map(\.weightKg) == [20, 37.5, 50])
    }

    @Test func setsFallingBackOnTheBarOrRepeatedAreDropped() {
        // 60 % de 35 = 21 → 20 (la barre, déjà là) ; 80 % = 28 → 27,5.
        let sets = WarmupPlanner.sets(firstWorkingKg: 35, rounding: bar, incrementKg: 2.5, maxCount: nil)
        #expect(sets.map(\.weightKg) == [20, 27.5])
    }

    @Test func aWorkingLoadOnTheBarNeedsNoWarmup() {
        #expect(WarmupPlanner.sets(firstWorkingKg: 20, rounding: bar, incrementKg: 2.5, maxCount: nil).isEmpty)
        #expect(WarmupPlanner.sets(firstWorkingKg: 0, rounding: .increment, incrementKg: 2.5, maxCount: nil).isEmpty)
    }

    @Test func theCountKeepsTheSetsClosestToTheWorkingLoad() {
        let one = WarmupPlanner.sets(firstWorkingKg: 100, rounding: bar, incrementKg: 2.5, maxCount: 1)
        #expect(one.map(\.weightKg) == [80])
        let two = WarmupPlanner.sets(firstWorkingKg: 100, rounding: bar, incrementKg: 2.5, maxCount: 2)
        #expect(two.map(\.weightKg) == [60, 80])
        #expect(WarmupPlanner.sets(firstWorkingKg: 100, rounding: bar, incrementKg: 2.5, maxCount: 0).isEmpty)
    }

    @Test func aZeroIncrementKeepsTheExactPercentage() {
        let sets = WarmupPlanner.sets(firstWorkingKg: 50, rounding: .increment, incrementKg: 0, maxCount: nil)
        #expect(sets.map(\.weightKg) == [30, 40])
    }

    @Test func eligibility() {
        // Un polyarticulaire, l'échauffement automatique activé, le muscle principal encore frais.
        #expect(WarmupPlanner.isEligible(autoWarmupEnabled: true, isCompound: true, warmupSetCount: nil,
                                         primaryMuscleAlreadyWorked: false))
        #expect(!WarmupPlanner.isEligible(autoWarmupEnabled: false, isCompound: true, warmupSetCount: nil,
                                          primaryMuscleAlreadyWorked: false))
        #expect(!WarmupPlanner.isEligible(autoWarmupEnabled: true, isCompound: true, warmupSetCount: nil,
                                          primaryMuscleAlreadyWorked: true))
        // Un isolé n'en a pas, sauf si son réglage en demande ; un réglage à 0 l'éteint.
        #expect(!WarmupPlanner.isEligible(autoWarmupEnabled: true, isCompound: false, warmupSetCount: nil,
                                          primaryMuscleAlreadyWorked: false))
        #expect(WarmupPlanner.isEligible(autoWarmupEnabled: true, isCompound: false, warmupSetCount: 1,
                                         primaryMuscleAlreadyWorked: false))
        #expect(!WarmupPlanner.isEligible(autoWarmupEnabled: true, isCompound: true, warmupSetCount: 0,
                                          primaryMuscleAlreadyWorked: false))
    }
}
