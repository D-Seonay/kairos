@testable import Pulse
import PulseDomain
import PulseLiveActivity
import PulseServices
import Testing

/// Les boutons Pause et Reprendre de la Live Activity de course passent par le seul service de course, puis la course des onglets
/// relit son état (spec V2a §4.4 ; revue V2a : câblage côté app).
@MainActor
@Suite struct SessionIntentWiringTests {
    @Test func pauseAndResumeReachTheRunService() async throws {
        let dependencies = AppDependencies.testing()
        let intents = SessionIntentWiring(service: dependencies.liveSession, runService: dependencies.run.service)
        _ = try await dependencies.run.service.start(.free())

        await intents.handle(RunControl.pause)
        #expect(await dependencies.run.service.current()?.isPaused == true)
        await intents.handle(RunControl.resume)
        #expect(await dependencies.run.service.current()?.isPaused == false)
    }

    @Test func theTabRunRereadsTheRunAfterAButton() async throws {
        let dependencies = AppDependencies.testing()
        try await dependencies.profiles.save(
            UserProfile(firstName: "Mathéo", onboardingCompletedAt: .now, createdAt: .now))
        let intents = SessionIntentWiring(service: dependencies.liveSession, runService: dependencies.run.service)
        let model = AppRootModel(dependencies: dependencies, sessionIntents: intents)
        await model.load()
        _ = try await dependencies.run.service.start(.free())

        await intents.handle(RunControl.pause)
        #expect(model.run?.current?.isPaused == true)
    }

    @Test func aStaleButtonWithoutARunChangesNothing() async {
        let dependencies = AppDependencies.testing()
        let intents = SessionIntentWiring(service: dependencies.liveSession, runService: dependencies.run.service)

        await intents.handle(RunControl.pause)
        await intents.handle(RunControl.resume)
        #expect(await dependencies.run.service.current() == nil)
    }
}
