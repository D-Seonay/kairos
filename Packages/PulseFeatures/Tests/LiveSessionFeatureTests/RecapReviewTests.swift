import Foundation
@testable import LiveSessionFeature
import PulseDomain
import PulseServices
import Testing

/// Les séries du bench validées dans l'ordre, au RPE donné.
@MainActor
private func validateBench(_ model: LiveSessionModel, rpes: [Double?]) async {
    for (index, rpe) in rpes.enumerated() {
        let set = model.session.exercises[0].sets[index]
        await model.tap(set: set.id)
        if let rpe { await model.setRPE(rpe, set: set.id) }
    }
}

/// Quatre séances Pulse terminées avant la séance du jour, sans bench : la séance du jour sera la 5e.
@MainActor
private func seedFourSessions(_ fixture: LiveFixture) async throws {
    for day in ["2026-10-05T08:00", "2026-10-12T08:00", "2026-10-19T08:00", "2026-10-26T08:00"] {
        let date = LiveClock.date(day)
        try await fixture.workouts.save(WorkoutSession(startedAt: date, kind: .strength, source: .pulse, status: .completed,
                                                       title: "Jambes", createdAt: date, updatedAt: date))
    }
}

@MainActor @Test func aFirstSessionWithoutRecordAsksForNoReview() async throws {
    let fixture = LiveFixture()
    let store = InMemoryReviewRequestStore()
    let live = try await fixture.startedModel()
    await validateBench(live, rpes: [8])
    let model = RecapModel(service: fixture.service, endedAt: LiveClock.date("2026-11-02T08:50"),
                           reviewPrompt: ReviewPrompt(store: store, appVersion: "1.0.4"))
    await model.load()
    #expect(model.recap?.beatenRecords.isEmpty == true)
    #expect(await model.save())
    #expect(!model.shouldRequestReview)
    #expect(store.lastRequestedVersion == nil)
}

@MainActor @Test func theFifthSessionAsksForAReviewOncePerVersion() async throws {
    let fixture = LiveFixture()
    try await seedFourSessions(fixture)
    let store = InMemoryReviewRequestStore()
    let live = try await fixture.startedModel()
    await validateBench(live, rpes: [8])
    let model = RecapModel(service: fixture.service, endedAt: LiveClock.date("2026-11-02T08:50"),
                           reviewPrompt: ReviewPrompt(store: store, appVersion: "1.0.4"))
    #expect(!model.shouldRequestReview)
    await model.load()
    #expect(await model.save())
    #expect(model.shouldRequestReview)
    #expect(store.lastRequestedVersion == "1.0.4")

    // Déjà demandé pour 1.0.4 : la séance suivante ne redemande pas.
    let next = LiveFixture()
    try await seedFourSessions(next)
    let again = try await next.startedModel()
    await validateBench(again, rpes: [8])
    let repeated = RecapModel(service: next.service, endedAt: LiveClock.date("2026-11-02T08:50"),
                              reviewPrompt: ReviewPrompt(store: store, appVersion: "1.0.4"))
    await repeated.load()
    #expect(await repeated.save())
    #expect(!repeated.shouldRequestReview)
}

@MainActor @Test func aWantedReviewIsHandedToTheScreenThatStays() async throws {
    // La demande ne part pas du récap, qui se ferme : la suite la signale avant de fermer la séance.
    let fixture = LiveFixture()
    try await seedFourSessions(fixture)
    var environment = fixture.environment
    environment.reviewPrompt = ReviewPrompt(store: InMemoryReviewRequestStore(), appVersion: "1.0.4")
    let session = try await fixture.service.start(LiveFixture.pushLaunch)
    let live = LiveSessionModel(session: session, environment: environment, haptics: fixture.haptics.haptics)
    await validateBench(live, rpes: [8])
    var wanted = 0
    var finished = 0
    let flow = FinishFlowModel(live: live, onFinished: { finished += 1 }, onReviewWanted: { wanted += 1 })
    await flow.finishTapped()
    await flow.confirm()?.value
    let recap = try #require(flow.recap)
    #expect(await recap.save())
    flow.recapSaved()
    #expect(wanted == 1 && finished == 1)
}
