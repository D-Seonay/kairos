import Foundation
import OnboardingFeature
import PulseDomain
import PulseServices
import Testing

@MainActor
struct OnboardingCompletionTests {
    private let now = OnboardingClock.now

    @Test func finishRequestsNotificationsAndCompletes() async throws {
        let fixture = OnboardingFixture()
        let model = fixture.makeModel()
        await OnboardingFixture.adoptRecommended(model)
        await model.finish()
        #expect(await fixture.notifications.requestCount == 1)
        #expect(model.profile.morningScoreNotification)
        #expect(model.profile.onboardingCompletedAt == now)
        #expect(fixture.stepStore.load() == nil)
        #expect(model.isFinished)
        let saved = try #require(await fixture.profiles.load())
        #expect(saved.onboardingCompletedAt == now)
    }

    @Test func finishWithoutNotificationsDoesNotAsk() async {
        let fixture = OnboardingFixture()
        let model = fixture.makeModel()
        await OnboardingFixture.adoptRecommended(model)
        model.notifyWhenScoreReady = false
        await model.finish()
        #expect(await fixture.notifications.requestCount == 0)
        #expect(!model.profile.morningScoreNotification)
        #expect(model.isFinished)
    }

    @Test func finishWithDeniedPermissionTurnsTheNotificationOff() async {
        let fixture = OnboardingFixture(notificationsGranted: false)
        let model = fixture.makeModel()
        await OnboardingFixture.adoptRecommended(model)
        await model.finish()
        #expect(await fixture.notifications.requestCount == 1)
        #expect(!model.profile.morningScoreNotification)
        #expect(model.isFinished)
    }

    @Test func emptyProfileStillCompletes() async {
        let model = OnboardingFixture(scenario: .noData).makeModel()
        await model.start()
        await model.begin()
        await model.skipHealth()
        await model.continueFromProfile()
        await model.continueFromGoals()
        await model.adoptProgram()
        model.checkIn.selection = [.sleep: 2, .pain: 2, .motivation: 2]
        await model.submitCheckIn()
        await model.finish()
        #expect(model.isFinished)
        #expect(model.profile.firstName == nil)
    }

    @Test func startEndsOnboardingWhenAProfileIsCompleted() async throws {
        let fixture = OnboardingFixture()
        try await fixture.profiles.save(OnboardingFixture.completedProfile())
        let model = fixture.makeModel()
        await model.start()
        #expect(model.isFinished)
    }

    @Test func restoredCompletedProfileEndsOnboarding() async throws {
        let fixture = OnboardingFixture()
        let model = fixture.makeModel()
        await OnboardingFixture.adoptRecommended(model)
        let draftID = model.profile.id
        let draftProgramID = try #require(model.profile.activeProgramID)
        let restored = OnboardingFixture.completedProfile()
        try await fixture.profiles.save(restored)
        let found = await model.checkForRestoredProfile()
        #expect(found)
        #expect(model.isFinished)
        #expect(try await fixture.profiles.load()?.id == restored.id)
        #expect(try await fixture.profiles.load()?.id != draftID)
        #expect(try await fixture.programs.program(id: draftProgramID) == nil)
    }

    @Test func noRestoredProfileKeepsTheDraft() async {
        let model = OnboardingFixture().makeModel()
        await model.start()
        await model.begin()
        let found = await model.checkForRestoredProfile()
        #expect(!found)
        #expect(!model.isFinished)
    }
}
