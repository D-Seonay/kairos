import HealthKit
import PulseDomain
import PulseHealth
import Testing

struct HealthKitWorkoutFamilyTests {
    @Test func typesFallIntoTheirFamily() {
        #expect(HealthKitWorkoutFamily.family(of: .swimming) == .endurance)
        #expect(HealthKitWorkoutFamily.family(of: .walking) == .walking)
        #expect(HealthKitWorkoutFamily.family(of: .hiking) == .walking)
        #expect(HealthKitWorkoutFamily.family(of: .rowing) == .endurance)
        #expect(HealthKitWorkoutFamily.family(of: .highIntensityIntervalTraining) == .intermittent)
        #expect(HealthKitWorkoutFamily.family(of: .boxing) == .intermittent)
        #expect(HealthKitWorkoutFamily.family(of: .traditionalStrengthTraining) == .strength)
        #expect(HealthKitWorkoutFamily.family(of: .functionalStrengthTraining) == .strength)
        #expect(HealthKitWorkoutFamily.family(of: .soccer) == .sports)
        #expect(HealthKitWorkoutFamily.family(of: .tennis) == .sports)
        #expect(HealthKitWorkoutFamily.family(of: .yoga) == .mobility)
        #expect(HealthKitWorkoutFamily.family(of: .pilates) == .mobility)
    }

    @Test func anUnknownTypeCountsAsEndurance() {
        #expect(HealthKitWorkoutFamily.family(of: .other) == .endurance)
    }

    @Test func runningAndCyclingAreReadAsSessions() {
        #expect(HealthKitWorkoutFamily.sessionTypes == [.running, .cycling])
    }
}
