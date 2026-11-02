import Foundation
@testable import LiveSessionFeature
import PulseDomain
import PulseServices
import Testing

/// Un snapshot dont on peut faire échouer l'effacement : `finish` a alors écrit la séance, mais le snapshot reste.
private actor ClearFailingStore: ActiveSessionStore {
    struct Failure: Error {}

    private let inner = InMemoryActiveSessionStore()
    private var failsOnClear = false

    func setFailsOnClear(_ value: Bool) {
        failsOnClear = value
    }

    func load() async throws -> ActiveSessionSnapshot? { try await inner.load() }
    func save(_ snapshot: ActiveSessionSnapshot) async throws { try await inner.save(snapshot) }

    func clear() async throws {
        if failsOnClear { throw Failure() }
        try await inner.clear()
    }
}

/// Bench puis pec deck, avec les trois séries du bench validées au RPE donné.
@MainActor
private func validateBench(_ model: LiveSessionModel, rpes: [Double?]) async {
    for (index, rpe) in rpes.enumerated() {
        let set = model.session.exercises[0].sets[index]
        await model.tap(set: set.id)
        if let rpe { await model.setRPE(rpe, set: set.id) }
    }
}

/// Les séances enregistrées pendant le test, sans l'historique de la semaine dernière.
@MainActor
private func savedSessions(_ fixture: LiveFixture) async throws -> [WorkoutSession] {
    try await fixture.workouts.sessions(from: LiveClock.date("2026-11-02T00:00"), to: .distantFuture)
}

@MainActor @Test func recapStartsOnTheSuggestedRPEAndSavesOnce() async throws {
    let fixture = LiveFixture()
    try await fixture.seedBenchHistory()
    let live = try await fixture.startedModel()
    await validateBench(live, rpes: [7, 8, 9])
    fixture.clock.set("2026-11-02T09:00")
    let endedAt = fixture.environment.now()

    let model = RecapModel(service: fixture.service, endedAt: endedAt)
    await model.load()
    let recap = try #require(model.recap)
    #expect(recap.suggestedRPE == 8)
    #expect(model.rpe == 8)
    #expect(model.loadSentence == recap.loadSentence(rpe: 8))
    model.rpe = 9
    #expect(model.loadSentence == recap.loadSentence(rpe: 9))
    model.note = "  Bonne séance  "

    #expect(await model.save())
    #expect(await model.save())
    let saved = try await savedSessions(fixture)
    #expect(saved.count == 1)
    let session = try #require(saved.first)
    #expect(session.overallRPE == 9)
    #expect(session.note == "Bonne séance")
    #expect(session.durationMinutes == 60)
    #expect(await fixture.service.current() == nil)
    #expect(model.errorMessage == nil)
    #expect(!model.isSaving)
}

@MainActor @Test func aFailedSaveStaysOpenAndRetries() async throws {
    let store = ClearFailingStore()
    let fixture = LiveFixture(store: store)
    try await fixture.seedBenchHistory()
    let live = try await fixture.startedModel()
    await validateBench(live, rpes: [nil])
    let model = RecapModel(service: fixture.service, endedAt: LiveClock.date("2026-11-02T08:45"))
    await model.load()
    #expect(model.rpe == 7)

    await store.setFailsOnClear(true)
    #expect(await model.save() == false)
    #expect(model.errorMessage != nil)
    #expect(!model.isSaving)
    #expect(await fixture.service.current() != nil)

    await store.setFailsOnClear(false)
    #expect(await model.save())
    #expect(model.errorMessage == nil)
    #expect(await fixture.service.current() == nil)
    let sessions = try await savedSessions(fixture)
    #expect(sessions.count == 1)
}

@MainActor @Test func laterSavesWithThePrePlacedRPE() async throws {
    let fixture = LiveFixture()
    try await fixture.seedBenchHistory()
    let live = try await fixture.startedModel()
    await validateBench(live, rpes: [8, 8])
    let model = RecapModel(service: fixture.service, endedAt: LiveClock.date("2026-11-02T08:50"))
    await model.load()
    model.rpe = 3
    model.note = "Épaule un peu raide"

    #expect(await model.later())
    let sessions = try await savedSessions(fixture)
    let session = try #require(sessions.first)
    #expect(sessions.count == 1)
    #expect(session.overallRPE == 8)
    #expect(session.note == "Épaule un peu raide")
    #expect(session.status == .completed)
}

@MainActor @Test func aRecapThatCannotLoadShowsAnErrorAndLoadsAgain() async throws {
    let fixture = LiveFixture()
    let model = RecapModel(service: fixture.service, endedAt: LiveClock.date("2026-11-02T08:50"))
    await model.load()
    #expect(model.recap == nil)
    #expect(model.errorMessage != nil)

    _ = try await fixture.startedModel()
    await model.load()
    #expect(model.recap != nil)
    #expect(model.errorMessage == nil)
}

@MainActor @Test func aForgottenSessionOffersTheSuggestedEnd() async throws {
    let fixture = LiveFixture()
    try await fixture.seedBenchHistory()
    let live = try await fixture.startedModel()
    await validateBench(live, rpes: [nil])
    // Sous 3 h sans action, la séance n'est pas oubliée.
    fixture.clock.set("2026-11-02T10:30")
    #expect(await fixture.service.suggestedEnd() == nil)

    // Le repos du bench est de 120 s : la série validée à 08:00 laisse 08:02 comme heure proposée.
    fixture.clock.set("2026-11-02T14:00")
    var finished = 0
    let flow = FinishFlowModel(live: live, onFinished: { finished += 1 })
    await flow.finishTapped()
    // Il reste des séries prévues : la confirmation d'abord.
    #expect(flow.confirmation == .unfinished(remaining: 4))
    #expect(flow.forgotten == nil)
    await flow.confirm()?.value
    let prompt = try #require(flow.forgotten)
    #expect(prompt.intent == .finish)
    #expect(FinishFlowModel.timeText(prompt.suggestedEnd, calendar: LiveClock.calendar) == "08:02")

    await flow.chooseEnd(usingSuggestion: true)?.value
    #expect(flow.forgotten == nil)
    let recap = try #require(flow.recap)
    #expect(recap.recap?.endedAt == prompt.suggestedEnd)
    #expect(recap.recap?.durationMinutes == 2)
    #expect(await recap.save())
    flow.recapSaved()
    #expect(finished == 1)
    #expect(flow.recap == nil)
}

@MainActor @Test func keepingTheCurrentTimeEndsTheSessionNow() async throws {
    let fixture = LiveFixture()
    try await fixture.seedBenchHistory()
    let live = try await fixture.startedModel()
    await validateBench(live, rpes: [nil])
    fixture.clock.set("2026-11-02T14:00")
    let flow = FinishFlowModel(live: live, onFinished: {})
    await flow.finishTapped()
    await flow.confirm()?.value
    await flow.chooseEnd(usingSuggestion: false)?.value
    #expect(flow.recap?.recap?.endedAt == LiveClock.date("2026-11-02T14:00"))
}

@MainActor @Test func finishingWithEverythingDoneSkipsTheConfirmationAndGoesToTheRecap() async throws {
    let fixture = LiveFixture()
    let live = try await fixture.startedModel(LiveFixture.plankLaunch)
    for set in live.session.exercises[0].sets { await live.tap(set: set.id) }
    fixture.clock.set("2026-11-02T08:10")
    let flow = FinishFlowModel(live: live, onFinished: {})
    await flow.finishTapped()
    #expect(flow.confirmation == nil)
    #expect(flow.forgotten == nil)
    #expect(flow.recap?.recap?.workingSets == 2)
}

@MainActor @Test func abandoningAsksFirstThenKeepsTheValidatedSetsAtTheSuggestedEnd() async throws {
    let fixture = LiveFixture()
    try await fixture.seedBenchHistory()
    let live = try await fixture.startedModel()
    await validateBench(live, rpes: [nil, nil])
    fixture.clock.set("2026-11-02T14:00")
    var finished = 0
    let flow = FinishFlowModel(live: live, onFinished: { finished += 1 })
    flow.abandonTapped()
    #expect(flow.confirmation == .abandon)
    await flow.confirm()?.value
    let prompt = try #require(flow.forgotten)
    #expect(prompt.intent == .abandon)
    await flow.chooseEnd(usingSuggestion: true)?.value
    #expect(finished == 1)
    #expect(flow.recap == nil)
    let sessions = try await savedSessions(fixture)
    let session = try #require(sessions.first)
    #expect(session.status == .abandoned)
    #expect(session.endedAt == prompt.suggestedEnd)
    #expect(session.sets.count == 2)
    #expect(await fixture.service.current() == nil)
}

@MainActor @Test func cancellingTheConfirmationLeavesTheSessionAlone() async throws {
    let fixture = LiveFixture()
    let live = try await fixture.startedModel()
    let flow = FinishFlowModel(live: live, onFinished: {})
    flow.abandonTapped()
    flow.cancelConfirmation()
    #expect(flow.confirmation == nil)
    #expect(await fixture.service.current() != nil)
}

@Test func theRemainingSetsAndTheTimeAreWrittenInFrench() {
    #expect(FinishFlowModel.remainingText(1) == "Il reste 1 série prévue")
    #expect(FinishFlowModel.remainingText(4) == "Il reste 4 séries prévues")
    #expect(FinishFlowModel.timeText(LiveClock.date("2026-11-02T08:41"), calendar: LiveClock.calendar) == "08:41")
    #expect(FinishFlowModel.timeText(LiveClock.date("2026-11-02T20:05"), calendar: LiveClock.calendar) == "20:05")
}

@MainActor @Test func theEffortIsNamedFromVeryEasyToMaximal() {
    let model = RecapModel(service: LiveFixture().service, endedAt: LiveClock.date("2026-11-02T09:00"))
    model.rpe = 1
    #expect(model.effortText == "1 · très facile")
    model.rpe = 7
    #expect(model.effortText == "7 · dur")
    #expect(model.effortSpokenText == "7 sur 10, dur")
    model.rpe = 10
    #expect(model.effortText == "10 · maximal")
}

@Test func theRecapSubtitleNamesTheSessionAndTheDay() {
    let ended = LiveClock.date("2026-11-02T09:00")
    #expect(RecapView.subtitle(title: "Pectoraux et triceps", endedAt: ended, calendar: LiveClock.calendar)
        == "Pectoraux et triceps · lundi 2 novembre")
    #expect(RecapView.subtitle(title: "", endedAt: ended, calendar: LiveClock.calendar) == "lundi 2 novembre")
    #expect(RecapView.setsText(1) == "1 série")
    #expect(RecapView.setsText(9) == "9 séries")
}

@MainActor @Test func aConfirmationClosedWithoutAButtonLeavesTheFlowAbleToPresentAgain() async throws {
    let fixture = LiveFixture()
    let live = try await fixture.startedModel()
    let flow = FinishFlowModel(live: live, onFinished: {})
    await flow.finishTapped()
    #expect(flow.confirmation != nil)
    // Le système ferme la fenêtre sans bouton : la liaison appelle `cancelConfirmation`.
    flow.cancelConfirmation()
    #expect(flow.confirmation == nil)
    await flow.finishTapped()
    #expect(flow.confirmation != nil)
    flow.cancelConfirmation()
    flow.abandonTapped()
    #expect(flow.confirmation == .abandon)
}

@MainActor @Test func aButtonResolvesTheConfirmationBeforeTheWindowClosesAfterIt() async throws {
    let fixture = LiveFixture()
    try await fixture.seedBenchHistory()
    let live = try await fixture.startedModel()
    await validateBench(live, rpes: [nil])
    let flow = FinishFlowModel(live: live, onFinished: {})
    await flow.finishTapped()
    let task = flow.confirm()
    // La fermeture de la fenêtre arrive après le bouton, avant que la tâche ne tourne.
    flow.cancelConfirmation()
    // Un second « Terminer » ou « Abandonner » attend la fin du premier.
    await flow.finishTapped()
    flow.abandonTapped()
    #expect(flow.confirmation == nil)
    await task?.value
    #expect(flow.recap != nil)
}

@MainActor @Test func aForgottenAlertClosedWithoutAButtonKeepsTheSessionOpenAndPresentsAgain() async throws {
    let fixture = LiveFixture()
    try await fixture.seedBenchHistory()
    let live = try await fixture.startedModel()
    await validateBench(live, rpes: [nil, nil, nil])
    fixture.clock.set("2026-11-02T14:00")
    let flow = FinishFlowModel(live: live, onFinished: {})
    flow.abandonTapped()
    await flow.confirm()?.value
    #expect(flow.forgotten != nil)
    flow.cancelForgotten()
    #expect(flow.forgotten == nil)
    #expect(flow.recap == nil)
    #expect(await fixture.service.current() != nil)
    flow.abandonTapped()
    #expect(flow.confirmation == .abandon)
}

@MainActor @Test func aButtonChoosesTheEndBeforeTheAlertClosesAfterIt() async throws {
    let fixture = LiveFixture()
    try await fixture.seedBenchHistory()
    let live = try await fixture.startedModel()
    await validateBench(live, rpes: [nil])
    fixture.clock.set("2026-11-02T14:00")
    var finished = 0
    let flow = FinishFlowModel(live: live, onFinished: { finished += 1 })
    flow.abandonTapped()
    await flow.confirm()?.value
    let task = flow.chooseEnd(usingSuggestion: true)
    flow.cancelForgotten()
    await task?.value
    #expect(finished == 1)
    #expect(await fixture.service.current() == nil)
}
