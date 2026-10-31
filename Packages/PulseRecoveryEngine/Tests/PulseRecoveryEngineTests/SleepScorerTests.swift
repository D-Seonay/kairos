@testable import PulseRecoveryEngine
import Testing

@Test func sleepScoreFullNight() { #expect(SleepScorer.score(asleepMinutes: 480, deepMinutes: 96) == 100) }
@Test func sleepScoreShortNightLowDeep() { #expect(abs(SleepScorer.score(asleepMinutes: 360, deepMinutes: 36) - 67.5) < 1e-9) }
@Test func sleepScoreCapsAtOne() { #expect(SleepScorer.score(asleepMinutes: 540, deepMinutes: 162) == 100) }
@Test func sleepScoreWithoutStagesUsesDurationOnly() { #expect(SleepScorer.score(asleepMinutes: 360, deepMinutes: nil) == 75) }
@Test func sleepScoreZeroMinutes() { #expect(SleepScorer.score(asleepMinutes: 0, deepMinutes: nil) == 0) }
