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
    // MARK: Stockage indisponible

    @Test func aStoreThatDidNotOpenShowsItsOwnScreenInsteadOfOnboarding() async throws {
        let dependencies = AppDependencies.testing(storeError: "Le stockage n'a pas pu être ouvert")
        let model = AppRootModel(dependencies: dependencies)
        await model.load()
        #expect(model.destination == .storageUnavailable)
        #expect(model.onboarding == nil && model.today == nil)
        // Seule une relance rouvre le magasin : pas de « Réessayer ».
        #expect(!model.canRetryStorage)
        // La Live Activity d'une séance que l'app ne peut pas lire n'est pas fermée.
        let activity = try #require(dependencies.sessionActivity as? StubSessionActivityController)
        #expect(await activity.endAllCalls.isEmpty)
    }

    // MARK: Course (revue V2a : câblage côté app)

    @Test func tabsCreateTheRunAndHandItToTheLiveActivityButtons() async throws {
        let dependencies = AppDependencies.testing()
        try await dependencies.profiles.save(Self.completedProfile())
        let intents = SessionIntentWiring(service: dependencies.liveSession, runService: dependencies.run.service)
        let model = AppRootModel(dependencies: dependencies, sessionIntents: intents)
        await model.load()
        let run = try #require(model.run)
        #expect(intents.runCoordinator === run)
        #expect(intents.coordinator === model.liveSession)
    }

    @Test func launchFollowsTheRunningRun() async throws {
        let dependencies = AppDependencies.testing()
        try await dependencies.profiles.save(Self.completedProfile())
        let snapshot = try await dependencies.run.service.start(.free())
        let model = AppRootModel(dependencies: dependencies)
        await model.load()
        #expect(model.run?.current?.sessionID == snapshot.sessionID)
    }

    @Test func erasingDropsTheRunAndDetachesTheButtons() async throws {
        let dependencies = AppDependencies.testing()
        try await dependencies.profiles.save(Self.completedProfile())
        let intents = SessionIntentWiring(service: dependencies.liveSession, runService: dependencies.run.service)
        let model = AppRootModel(dependencies: dependencies, sessionIntents: intents)
        await model.load()
        #expect(model.run != nil)
        try await dependencies.eraser.eraseEverything(options: EraseOptions(includeAppleHealth: false))
        await model.dataErased()
        #expect(model.run == nil)
        #expect(intents.runCoordinator == nil && intents.coordinator == nil)
    }

    @Test func erasingDiscardsTheRunningRun() async throws {
        let dependencies = AppDependencies.testing()
        try await dependencies.profiles.save(Self.completedProfile())
        _ = try await dependencies.run.service.start(.free())
        let model = AppRootModel(dependencies: dependencies)
        await model.load()
        try await dependencies.eraser.eraseEverything(options: EraseOptions(includeAppleHealth: false))
        await model.dataErased()
        #expect(await dependencies.run.service.current() == nil)
        #expect(await dependencies.run.service.recoveryOffer() == nil)
    }

    /// Deux retours rapprochés ne relisent les onglets qu'une fois ; une donnée changée hors des écrans fait relire au retour
    /// suivant, et le passage de minuit aussi.
    @Test func closeActivationsReloadTheTabsOnceAndMidnightStillReloads() async throws {
        let dependencies = AppDependencies.testing()
        try await dependencies.profiles.save(Self.completedProfile())
        let model = AppRootModel(dependencies: dependencies, changes: NotificationCenter())
        await model.load()
        let calendar = dependencies.calendar
        let noon = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 27, hour: 12)))
        await model.becameActive(at: noon)
        #expect(model.activationReloads == 1)
        await model.becameActive(at: noon.addingTimeInterval(120))
        #expect(model.activationReloads == 1)
        model.noteDataChange()
        await model.becameActive(at: noon.addingTimeInterval(180))
        #expect(model.activationReloads == 2)
        // 23 h 57 relit (dernière relecture trop vieille) ; 0 h 01, quatre minutes plus tard, relit parce que le jour a changé.
        let lateEvening = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 27, hour: 23, minute: 57)))
        await model.becameActive(at: lateEvening)
        #expect(model.activationReloads == 3)
        await model.becameActive(at: lateEvening.addingTimeInterval(240))
        #expect(model.activationReloads == 4)
    }
}
