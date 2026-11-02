import Foundation
@testable import Pulse
import PulseDomain
import PulseRecoveryEngine
import PulseServices
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

    @Test func launchClosesLiveActivitiesWithoutASession() async throws {
        let dependencies = AppDependencies.testing()
        try await dependencies.profiles.save(Self.completedProfile())
        let model = AppRootModel(dependencies: dependencies)
        await model.load()
        let activity = try #require(dependencies.sessionActivity as? StubSessionActivityController)
        #expect(model.liveSession != nil && model.liveSession?.current == nil)
        #expect(await activity.endAllCalls == [nil])
    }

    @Test func launchKeepsTheActivityOfTheRunningSession() async throws {
        let dependencies = AppDependencies.testing()
        try await dependencies.profiles.save(Self.completedProfile())
        let session = try await dependencies.liveSession.start(.free(policy: ProgressionPolicy(allowsIncrease: true)))
        let model = AppRootModel(dependencies: dependencies)
        await model.load()
        let activity = try #require(dependencies.sessionActivity as? StubSessionActivityController)
        #expect(model.liveSession?.current?.id == session.id)
        #expect(await activity.endAllCalls == [session.id])
    }

    @Test func erasingDiscardsTheRunningSession() async throws {
        let dependencies = AppDependencies.testing()
        try await dependencies.profiles.save(Self.completedProfile())
        _ = try await dependencies.liveSession.start(.free(policy: ProgressionPolicy(allowsIncrease: true)))
        let model = AppRootModel(dependencies: dependencies)
        await model.load()
        try await dependencies.eraser.eraseEverything(options: EraseOptions(includeAppleHealth: false))
        await model.dataErased()
        let activity = try #require(dependencies.sessionActivity as? StubSessionActivityController)
        #expect(model.liveSession == nil)
        #expect(await dependencies.liveSession.current() == nil)
        #expect(await activity.endAllCalls.last == .some(nil))
    }
}
