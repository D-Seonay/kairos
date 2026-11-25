@testable import PulseRecoveryEngine
import Testing

@Test func sleepScoreFullNight() { #expect(SleepScorer.score(asleepMinutes: 480, deepMinutes: 96) == 100) }
@Test func sleepScoreShortNightLowDeep() { #expect(abs(SleepScorer.score(asleepMinutes: 360, deepMinutes: 36) - 67.5) < 1e-9) }
@Test func sleepScoreCapsAtOne() { #expect(SleepScorer.score(asleepMinutes: 540, deepMinutes: 162) == 100) }
@Test func sleepScoreWithoutStagesUsesDurationOnly() { #expect(SleepScorer.score(asleepMinutes: 360, deepMinutes: nil) == 75) }
@Test func sleepScoreZeroMinutes() { #expect(SleepScorer.score(asleepMinutes: 0, deepMinutes: nil) == 0) }

@Test func targetDrivesTheWholeScoreWithoutStages() {
    #expect(SleepScorer.score(asleepMinutes: 420, deepMinutes: nil, targetMinutes: 420) == 100)
    #expect(SleepScorer.score(asleepMinutes: 420, deepMinutes: nil) == 87.5)
    #expect(SleepScorer.score(asleepMinutes: 210, deepMinutes: nil, targetMinutes: 420) == 50)
}

@Test func targetDrivesSeventyPointsWithStages() {
    #expect(SleepScorer.score(asleepMinutes: 420, deepMinutes: 84, targetMinutes: 420) == 100)
    #expect(abs(SleepScorer.score(asleepMinutes: 390, deepMinutes: 39, targetMinutes: 420) - 80) < 1e-9)
    #expect(SleepScorer.score(asleepMinutes: 420, deepMinutes: 84) == 91.25)
}

@Test func sleepingPastTheTargetIsCapped() {
    #expect(SleepScorer.score(asleepMinutes: 600, deepMinutes: nil, targetMinutes: 420) == 100)
}
