import PulseDomain
import Testing

@Test func goalDefaultsToEightHours() {
    #expect(SleepGoal.minutes(of: nil) == 480)
    #expect(SleepGoal.minutes(of: UserProfile()) == 480)
}

@Test func goalIsClampedToItsRange() {
    #expect(SleepGoal.minutes(of: UserProfile(sleepGoalMinutes: 0)) == 360)
    #expect(SleepGoal.minutes(of: UserProfile(sleepGoalMinutes: -30)) == 360)
    #expect(SleepGoal.minutes(of: UserProfile(sleepGoalMinutes: 2000)) == 600)
    #expect(SleepGoal.minutes(of: UserProfile(sleepGoalMinutes: 420)) == 420)
}

@Test func shortNightIsOneHourUnderTheGoal() {
    #expect(SleepGoal.isShortNight(asleepMinutes: 419, goalMinutes: 480))
    #expect(!SleepGoal.isShortNight(asleepMinutes: 420, goalMinutes: 480))
    #expect(SleepGoal.isShortNight(asleepMinutes: 359, goalMinutes: 420))
    #expect(!SleepGoal.isShortNight(asleepMinutes: 360, goalMinutes: 420))
}
