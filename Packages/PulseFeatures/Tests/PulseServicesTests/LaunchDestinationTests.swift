import Foundation
import PulseDomain
import PulseServices
import Testing

struct LaunchDestinationTests {
    @Test func launchDestination() {
        #expect(LaunchDestination.resolve(profile: nil) == .onboarding)
        #expect(LaunchDestination.resolve(profile: UserProfile()) == .onboarding)
        let done = UserProfile(onboardingCompletedAt: TestClock.date("2026-11-02T08:00"))
        #expect(LaunchDestination.resolve(profile: done) == .main)
    }
}
