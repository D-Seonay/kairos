import Testing
@testable import PulseRecoveryEngine

@Test(arguments: [
    (48.0, 50.0, 100.0), (50.0, 50.0, 100.0), (52.0, 50.0, 83.0), (57.0, 50.0, 40.5),
    (59.0, 50.0, 20.0), (62.0, 50.0, 0.0), (70.0, 50.0, 0.0),
])
func rhrScore(today: Double, baseline: Double, expected: Double) {
    #expect(abs(RHRScorer.score(todayBpm: today, baselineMeanBpm: baseline) - expected) < 1e-9)
}
