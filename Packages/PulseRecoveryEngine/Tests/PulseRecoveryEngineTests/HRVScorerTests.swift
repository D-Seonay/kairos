@testable import PulseRecoveryEngine
import Testing

@Test(arguments: [
    (2.0, 100.0), (0.5, 100.0),
    (0.0, 90.0), (-0.5, 80.0),
    (-1.0, 65.0), (-1.5, 50.0),
    (-2.0, 37.5), (-3.5, 10.0), (-10.0, 10.0)
])
func hrvScoreTiers(z: Double, expected: Double) {
    #expect(abs(HRVScorer.score(zScore: z) - expected) < 1e-9)
}
