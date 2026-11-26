import Foundation
import OnboardingFeature
import PulseDomain
import PulseServices
import Testing

/// L'étape Apple Santé de l'onboarding et la demande d'accès qu'elle retient ou non.
@MainActor
struct OnboardingHealthAccessTests {
    /// « Autoriser » retient que la demande d'accès a été faite ; « Plus tard » et une demande qui échoue la laissent à faire :
    /// les Paramètres et la bannière du check-in offriront « Connecter Apple Santé ».
    @Test func onlyAnAllowedHealthStepRemembersTheRequest() async {
        let allowed = OnboardingFixture()
        let allowing = allowed.makeModel()
        await allowing.start()
        await allowing.allowHealth()
        #expect(allowed.environment.once.hasHappened(.healthAccessRequest))

        let skipped = OnboardingFixture()
        let skipping = skipped.makeModel()
        await skipping.start()
        await skipping.skipHealth()
        #expect(!skipped.environment.once.hasHappened(.healthAccessRequest))

        let unavailable = OnboardingFixture(health: UnavailableHealthSource())
        let failing = unavailable.makeModel()
        await failing.start()
        await failing.allowHealth()
        #expect(failing.step == .profile)
        #expect(!unavailable.environment.once.hasHappened(.healthAccessRequest))
    }
}
