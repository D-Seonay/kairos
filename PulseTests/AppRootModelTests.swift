import Foundation
@testable import Pulse
import PulseDomain
import Testing

@MainActor
@Suite struct AppRootModelTests {
    private static let day = Date(timeIntervalSince1970: 1_793_000_000)

    private static func completedProfile() -> UserProfile {
        UserProfile(firstName: "Mathéo", onboardingCompletedAt: day, createdAt: day)
    }

    @Test func freshInstallGoesToOnboarding() async {
        let model = AppRootModel(dependencies: .testing())
        #expect(model.destination == .loading)
        await model.load()
        #expect(model.destination == .onboarding)
        #expect(model.onboarding != nil && model.today == nil)
    }

    @Test func completedProfileGoesToMain() async throws {
        let dependencies = AppDependencies.testing()
        try await dependencies.profiles.save(Self.completedProfile())
        let model = AppRootModel(dependencies: dependencies)
        await model.load()
        #expect(model.destination == .main)
        #expect(model.today != nil && model.onboarding == nil)
        #expect(model.profile?.firstName == "Mathéo")
    }

    @Test func erasingReturnsToOnboarding() async throws {
        let dependencies = AppDependencies.testing()
        try await dependencies.profiles.save(Self.completedProfile())
        let model = AppRootModel(dependencies: dependencies)
        await model.load()
        #expect(model.destination == .main)
        try await dependencies.eraser.eraseEverything(options: EraseOptions(includeAppleHealth: false))
        await model.dataErased()
        #expect(model.destination == .onboarding)
        #expect(model.profile == nil && model.onboarding != nil && model.today == nil)
    }

    @Test func finishingOnboardingShowsTheTabs() async {
        let model = AppRootModel(dependencies: .testing())
        await model.load()
        model.onboardingFinished()
        #expect(model.destination == .main)
        #expect(model.today != nil && model.onboarding == nil)
    }
}
