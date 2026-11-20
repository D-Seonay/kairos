import PulseDomain
@testable import PulseRecoveryEngine
import Testing

struct EquivalentLoadTests {
    @Test func sameEquipmentKeepsTheStrengthAndAimsAtTheTargetReps() throws {
        // 1RM 100 kg, 8 répétitions visées : 100 × (37 − 8) / 36 = 80,56 → 80.
        let load = try #require(EquivalentLoad.estimate(oneRepMaxKg: 100, switching: (.barbell, .barbell), targetReps: 8,
                                                        rounding: .plates(barKg: 20, smallestPlateKg: 1.25), incrementKg: 2.5))
        #expect(load == 80)
    }

    @Test func movingToDumbbellsLowersTheLoad() throws {
        let barbell = try #require(EquivalentLoad.estimate(oneRepMaxKg: 100, switching: (.barbell, .barbell), targetReps: 10,
                                                           rounding: .increment, incrementKg: 2))
        let dumbbell = try #require(EquivalentLoad.estimate(oneRepMaxKg: 100, switching: (.barbell, .dumbbell), targetReps: 10,
                                                            rounding: .increment, incrementKg: 2))
        #expect(dumbbell < barbell)
        #expect(dumbbell.truncatingRemainder(dividingBy: 2) == 0)
    }

    @Test func theTableIsSymmetric() throws {
        let there = try #require(EquivalentLoad.coefficient(from: .barbell, to: .machine))
        let back = try #require(EquivalentLoad.coefficient(from: .machine, to: .barbell))
        #expect(abs(there * back - 1) < 1e-9)
        #expect(EquivalentLoad.coefficient(from: .cable, to: .cable) == 1)
        #expect(EquivalentLoad.coefficient(from: .barbell, to: .band) == nil)
    }

    @Test func noEstimateWithoutAUsableLoad() {
        #expect(EquivalentLoad.estimate(oneRepMaxKg: 0, switching: (.barbell, .dumbbell), targetReps: 8,
                                        rounding: .increment, incrementKg: 2) == nil)
        #expect(EquivalentLoad.estimate(oneRepMaxKg: 100, switching: (.barbell, .bodyweight), targetReps: 8,
                                        rounding: .increment, incrementKg: 2) == nil)
        #expect(EquivalentLoad.estimate(oneRepMaxKg: 100, switching: (.barbell, .dumbbell), targetReps: 0,
                                        rounding: .increment, incrementKg: 2) == nil)
    }

    @Test func aBarbellEstimateNeverGoesBelowTheBar() throws {
        let load = try #require(EquivalentLoad.estimate(oneRepMaxKg: 6, switching: (.dumbbell, .barbell), targetReps: 12,
                                                        rounding: .plates(barKg: 20, smallestPlateKg: 1.25), incrementKg: 2.5))
        #expect(load == 20)
    }
}
