import PulseDomain
@testable import PulseRecoveryEngine
import Testing

struct ProgressionPolicyTests {
    private func allowsIncrease(_ recovery: DailyRecovery?, adaptation: Bool = true, original: Bool = false) -> Bool {
        ProgressionPolicy.make(recovery: recovery, adaptationEnabled: adaptation, startsOriginalAfterOverreach: original).allowsIncrease
    }

    @Test func policyFollowsTheDayTable() {
        #expect(ProgressionPolicy.make(recovery: nil, adaptationEnabled: true, startsOriginalAfterOverreach: false).allowsIncrease)
        #expect(ProgressionPolicy.make(recovery: .measured(score: 72), adaptationEnabled: true,
                                       startsOriginalAfterOverreach: false).allowsIncrease)
        #expect(ProgressionPolicy.make(recovery: .measured(score: 72, missing: [.hrv]), adaptationEnabled: true,
                                       startsOriginalAfterOverreach: false).allowsIncrease)
        #expect(!ProgressionPolicy.make(recovery: .measured(score: 55), adaptationEnabled: true,
                                        startsOriginalAfterOverreach: false).allowsIncrease)
        #expect(!ProgressionPolicy.make(recovery: .estimated(score: 92), adaptationEnabled: true,
                                        startsOriginalAfterOverreach: false).allowsIncrease)
        #expect(!ProgressionPolicy.make(recovery: .measured(score: 92, calibrating: 8), adaptationEnabled: true,
                                        startsOriginalAfterOverreach: false).allowsIncrease)
        #expect(!ProgressionPolicy.make(recovery: .measured(score: 30), adaptationEnabled: true,
                                        startsOriginalAfterOverreach: true).allowsIncrease)
        #expect(ProgressionPolicy.make(recovery: .measured(score: 55), adaptationEnabled: false,
                                       startsOriginalAfterOverreach: false).allowsIncrease)
    }

    @Test func optimalAndNormalScoresAllowTheIncrease() {
        #expect(allowsIncrease(.measured(score: 95)))
        #expect(allowsIncrease(.measured(score: 65)))
        #expect(allowsIncrease(.measured(score: 89, missing: [.hrv, .sleep, .restingHeartRate])))
    }

    @Test func overreachBlocksTheIncreaseWithOrWithoutTheOriginalSession() {
        #expect(!allowsIncrease(.measured(score: 30)))
        #expect(!allowsIncrease(.measured(score: 30), original: true))
        #expect(!allowsIncrease(.measured(score: 80), original: true))
    }

    @Test func calibrationBlocksTheIncreaseEvenWithAnOptimalScore() {
        #expect(!allowsIncrease(.measured(score: 95, calibrating: 1)))
    }

    @Test func disabledAdaptationAlwaysAllowsTheIncrease() {
        #expect(allowsIncrease(.measured(score: 30), adaptation: false, original: true))
        #expect(allowsIncrease(.estimated(score: 50), adaptation: false))
    }
}
