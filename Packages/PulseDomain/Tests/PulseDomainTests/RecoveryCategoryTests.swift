@testable import PulseDomain
import Testing

@Test(arguments: [
    (100.0, RecoveryCategory.optimal), (90.0, .optimal), (89.99, .normal),
    (65.0, .normal), (64.99, .moderateFatigue), (40.0, .moderateFatigue),
    (39.99, .overreached), (0.0, .overreached)
])
func categoryThresholds(score: Double, expected: RecoveryCategory) {
    #expect(RecoveryCategory(score: score) == expected)
}
