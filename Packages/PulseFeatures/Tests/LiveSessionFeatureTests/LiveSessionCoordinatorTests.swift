import Foundation
@testable import LiveSessionFeature
import PulseDomain
import PulseServices
import Testing

@MainActor @Test func doubleStartPresentsOnce() async throws {
    let fixture = LiveFixture()
    let coordinator = fixture.coordinator()
    async let first: Void = coordinator.start(LiveFixture.pushLaunch)
    async let second: Void = coordinator.start(LiveFixture.pushLaunch)
    _ = await (first, second)
    #expect(coordinator.isPresented)
    #expect(coordinator.errorMessage == nil)
    let stored = await fixture.service.current()
    #expect(stored != nil)
    #expect(coordinator.current == stored)
    #expect(await fixture.activity.states.count == 1)
}

@MainActor @Test func startingWithASessionInProgressPresentsTheOneInProgress() async throws {
    let fixture = LiveFixture()
    let coordinator = fixture.coordinator()
    await coordinator.start(LiveFixture.pushLaunch)
    let first = try #require(coordinator.current)
    coordinator.isPresented = false
    await coordinator.start(LiveFixture.plankLaunch)
    #expect(coordinator.isPresented)
    #expect(coordinator.current?.id == first.id)
    #expect(coordinator.errorMessage == nil)
}

@MainActor @Test func startingWhileAnUnseenSessionIsStoredPresentsIt() async throws {
    let fixture = LiveFixture()
    let stored = try await fixture.service.start(LiveFixture.pushLaunch)
    let coordinator = fixture.coordinator()
    await coordinator.start(LiveFixture.plankLaunch)
    #expect(coordinator.isPresented)
    #expect(coordinator.current?.id == stored.id)
    #expect(coordinator.errorMessage == nil)
}

@MainActor @Test func aStoredSessionShowsTheResumeBanner() async throws {
    let fixture = LiveFixture()
    let stored = try await fixture.service.start(LiveFixture.pushLaunch)
    let coordinator = fixture.coordinator()
    #expect(coordinator.current == nil)
    await coordinator.refresh()
    #expect(coordinator.current == stored)
    #expect(!coordinator.isPresented)
    coordinator.resume()
    #expect(coordinator.isPresented)
    #expect(coordinator.model().session == stored)
}

@MainActor @Test func refreshWithoutASessionClearsTheBanner() async throws {
    let fixture = LiveFixture()
    let coordinator = fixture.coordinator()
    await coordinator.start(LiveFixture.pushLaunch)
    _ = try await fixture.service.abandon(endedAt: LiveClock.date("2026-11-02T08:30"))
    await coordinator.refresh()
    #expect(coordinator.current == nil)
    #expect(!coordinator.isPresented)
}

@MainActor @Test func refreshKeepsTheModelAndTakesTheChangesMadeElsewhere() async throws {
    let fixture = LiveFixture()
    try await fixture.seedBenchHistory()
    let coordinator = fixture.coordinator()
    await coordinator.start(LiveFixture.pushLaunch)
    let model = coordinator.model()
    #expect(coordinator.model() === model)
    let set = model.session.exercises[0].sets[0].id
    let exercise = model.session.exercises[0].id
    _ = try await fixture.service.apply(.validate(exercise: exercise, set: set))
    await coordinator.refresh()
    #expect(coordinator.model() === model)
    #expect(model.session.exercises[0].sets[0].completedAt != nil)
    #expect(coordinator.current == model.session)
}

@MainActor @Test func abandonFromTheBannerClosesTheSession() async throws {
    let fixture = LiveFixture()
    try await fixture.seedBenchHistory()
    let coordinator = fixture.coordinator()
    await coordinator.start(LiveFixture.pushLaunch)
    let model = coordinator.model()
    await model.tap(set: model.session.exercises[0].sets[0].id)
    coordinator.isPresented = false
    await coordinator.abandonFromBanner()
    #expect(coordinator.current == nil)
    #expect(await fixture.service.current() == nil)
    let saved = try await fixture.workouts.sessions(from: .distantPast, to: .distantFuture)
    #expect(saved.contains { $0.status == .abandoned && $0.sets.count == 1 })
    #expect(coordinator.errorMessage == nil)
}

@MainActor @Test func abandonFromTheBannerClosesAForgottenSessionAtItsSuggestedEnd() async throws {
    let fixture = LiveFixture()
    try await fixture.seedBenchHistory()
    let coordinator = fixture.coordinator()
    await coordinator.start(LiveFixture.pushLaunch)
    let model = coordinator.model()
    await model.tap(set: model.session.exercises[0].sets[0].id)
    fixture.clock.set("2026-11-02T20:00")
    await coordinator.abandonFromBanner()
    let saved = try await fixture.workouts.sessions(from: .distantPast, to: .distantFuture)
    #expect(saved.first { $0.status == .abandoned }?.endedAt == LiveClock.date("2026-11-02T08:02"))
}

@MainActor @Test func didFinishDropsTheSessionAndItsModel() async throws {
    let fixture = LiveFixture()
    let coordinator = fixture.coordinator()
    await coordinator.start(LiveFixture.pushLaunch)
    let model = coordinator.model()
    _ = try await fixture.service.abandon(endedAt: LiveClock.date("2026-11-02T08:30"))
    coordinator.didFinish()
    #expect(coordinator.current == nil)
    #expect(!coordinator.isPresented)
    await coordinator.start(LiveFixture.plankLaunch)
    #expect(coordinator.model() !== model)
    #expect(coordinator.model().session.title == "Gainage")
}

@MainActor @Test func notificationsAreRequestedOncePerLaunch() async throws {
    let fixture = LiveFixture()
    let coordinator = fixture.coordinator()
    await coordinator.start(LiveFixture.pushLaunch)
    _ = try await fixture.service.abandon(endedAt: LiveClock.date("2026-11-02T08:30"))
    coordinator.didFinish()
    await coordinator.start(LiveFixture.plankLaunch)
    #expect(await fixture.authorizer.requestCount == 1)
    #expect(coordinator.notice == nil)
}

@MainActor @Test func deniedNotificationsAreSaidOnce() async throws {
    let fixture = LiveFixture(notificationsGranted: false)
    let coordinator = fixture.coordinator()
    await coordinator.start(LiveFixture.pushLaunch)
    #expect(coordinator.notice == "Notifications désactivées : la fin du repos ne sonnera pas écran verrouillé. "
        + "Tu peux les activer dans Réglages.")
    #expect(coordinator.isPresented)
    coordinator.dismissNotice()
    #expect(coordinator.notice == nil)
    _ = try await fixture.service.abandon(endedAt: LiveClock.date("2026-11-02T08:30"))
    coordinator.didFinish()
    await coordinator.start(LiveFixture.plankLaunch)
    #expect(coordinator.notice == nil)
    #expect(await fixture.authorizer.requestCount == 1)
}

@MainActor @Test func presentingAnExistingSessionNeitherAsksNorWarnsAboutNotifications() async throws {
    let fixture = LiveFixture(notificationsGranted: false)
    _ = try await fixture.service.start(LiveFixture.pushLaunch)
    let coordinator = fixture.coordinator()
    await coordinator.refresh()
    await coordinator.start(LiveFixture.plankLaunch)
    #expect(coordinator.isPresented)
    #expect(coordinator.notice == nil)
    #expect(await fixture.authorizer.requestCount == 0)
    let unseen = fixture.coordinator()
    await unseen.start(LiveFixture.plankLaunch)
    #expect(unseen.isPresented)
    #expect(unseen.notice == nil)
    #expect(await fixture.authorizer.requestCount == 0)
}

@MainActor @Test func theFirstFreshStartAfterAnExistingOneStillAsks() async throws {
    let fixture = LiveFixture(notificationsGranted: false)
    let coordinator = fixture.coordinator()
    await coordinator.start(LiveFixture.pushLaunch)
    #expect(coordinator.notice != nil)
    #expect(await fixture.authorizer.requestCount == 1)
}

/// Un snapshot qu'on ne peut pas enregistrer : aucune séance ne démarre.
private actor SaveFailingStore: ActiveSessionStore {
    struct Failure: Error {}

    func load() async throws -> ActiveSessionSnapshot? { nil }
    func save(_ snapshot: ActiveSessionSnapshot) async throws { throw Failure() }
    func clear() async throws {}
}

@MainActor @Test func aFailedStartShowsAnErrorUntilDismissed() async {
    let fixture = LiveFixture(store: SaveFailingStore())
    let coordinator = fixture.coordinator()
    await coordinator.start(LiveFixture.pushLaunch)
    #expect(coordinator.errorMessage != nil)
    #expect(!coordinator.isPresented && coordinator.current == nil)
    coordinator.dismissError()
    #expect(coordinator.errorMessage == nil)
}
