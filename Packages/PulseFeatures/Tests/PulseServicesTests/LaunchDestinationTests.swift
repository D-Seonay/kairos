import Foundation
import PulseDomain
import PulseServices
import Testing

struct LaunchDestinationTests {
    private struct ReadFailure: Error {}

    private static let done = UserProfile(onboardingCompletedAt: TestClock.date("2026-11-02T08:00"))

    @Test func launchDestination() {
        #expect(LaunchDestination.resolve(profile: nil) == .onboarding)
        #expect(LaunchDestination.resolve(profile: UserProfile()) == .onboarding)
        #expect(LaunchDestination.resolve(profile: Self.done) == .main)
    }

    @Test func anOpenedAndReadableStoreFollowsTheProfile() {
        #expect(LaunchDestination.resolve(storeOpened: true, profile: .success(nil)) == .onboarding)
        #expect(LaunchDestination.resolve(storeOpened: true, profile: .success(Self.done)) == .main)
    }

    /// Le magasin de secours en mémoire est vide : sans ce cas, l'app montrerait l'onboarding à quelqu'un qui a des données.
    @Test func aStoreThatDidNotOpenNeverShowsOnboarding() {
        #expect(LaunchDestination.resolve(storeOpened: false, profile: .success(nil)) == .storageUnavailable)
        #expect(LaunchDestination.resolve(storeOpened: false, profile: .success(Self.done)) == .storageUnavailable)
    }

    @Test func aProfileThatCannotBeReadIsNotAMissingProfile() {
        #expect(LaunchDestination.resolve(storeOpened: true, profile: .failure(ReadFailure())) == .storageUnavailable)
    }
}
