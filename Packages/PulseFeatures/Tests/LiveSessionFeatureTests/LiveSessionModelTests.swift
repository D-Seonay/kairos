import Foundation
@testable import LiveSessionFeature
import PulseDomain
import PulseServices
import Testing

@MainActor
private func field(_ model: LiveSessionModel, exercise: Int = 0, set: Int, _ kind: KeypadField.Kind) -> KeypadField {
    KeypadField(exercise: model.session.exercises[exercise].id, set: model.session.exercises[exercise].sets[set].id, kind: kind)
}

@MainActor @Test func nextMovesFromWeightToRepsThenToTheNextSet() async throws {
    let fixture = LiveFixture()
    try await fixture.seedBenchHistory()
    let model = try await fixture.startedModel()
    let before = model.session
    model.focus(field(model, set: 0, .weight))
    #expect(model.keypad.text == "62,5")
    await model.keypadKey(.next)
    #expect(model.focus == field(model, set: 0, .reps))
    await model.keypadKey(.next)
    #expect(model.focus == field(model, set: 1, .weight))
    #expect(model.session == before)
    model.focus(field(model, set: 2, .reps))
    await model.keypadKey(.next)
    #expect(model.focus == nil)
}

@MainActor @Test func keypadKeysEditTheFocusedValueEachTime() async throws {
    let fixture = LiveFixture()
    try await fixture.seedBenchHistory()
    let model = try await fixture.startedModel()
    model.focus(field(model, set: 0, .weight))
    await model.keypadKey(.plus)
    #expect(model.session.exercises[0].sets[0].weightKg == 65)
    #expect(model.session.exercises[0].sets[0].isEdited)
    await model.keypadKey(.delete)
    await model.keypadKey(.comma)
    await model.keypadKey(.digit(5))
    #expect(model.session.exercises[0].sets[0].weightKg == 6.5)
    for _ in 1...3 { await model.keypadKey(.delete) }
    #expect(model.session.exercises[0].sets[0].weightKg == nil)
    #expect(fixture.haptics.light == 7)
    let stored = await fixture.service.current()
    #expect(stored == model.session)
}

@MainActor @Test func keypadKeysEditTheRepsAndTheSeconds() async throws {
    let fixture = LiveFixture()
    let model = try await fixture.startedModel(LiveFixture.plankLaunch)
    #expect(model.session.exercises[0].tracksDuration)
    model.focus(field(model, set: 0, .duration))
    await model.keypadKey(.digit(4))
    await model.keypadKey(.digit(5))
    #expect(model.session.exercises[0].sets[0].durationSeconds == 45)
    let bench = try await LiveFixture().startedModel()
    bench.focus(field(bench, set: 0, .reps))
    await bench.keypadKey(.digit(9))
    #expect(bench.session.exercises[0].sets[0].reps == 9)
}

@MainActor @Test func tappingTheCheckValidatesProposedValues() async throws {
    let fixture = LiveFixture()
    try await fixture.seedBenchHistory()
    let model = try await fixture.startedModel()
    let set = model.session.exercises[0].sets[0]
    await model.tap(set: set.id)
    let done = model.session.exercises[0].sets[0]
    #expect(done.completedAt == LiveClock.date("2026-11-02T08:00"))
    #expect(done.weightKg == set.proposed.weightKg)
    #expect(done.reps == set.proposed.reps)
    #expect(model.session.rest?.endsAt == LiveClock.date("2026-11-02T08:02"))
    #expect(model.focus == nil)
    #expect(fixture.haptics.validation == 1)
    #expect(model.errorMessage == nil)
    #expect(!model.isSaving)
}

@MainActor @Test func tappingAValidatedCheckUnvalidatesIt() async throws {
    let fixture = LiveFixture()
    try await fixture.seedBenchHistory()
    let model = try await fixture.startedModel()
    let set = model.session.exercises[0].sets[0]
    await model.tap(set: set.id)
    await model.tap(set: set.id)
    #expect(model.session.exercises[0].sets[0].completedAt == nil)
    #expect(model.session.rest == nil)
    #expect(fixture.haptics.validation == 1)
}

@MainActor @Test func tappingAnEmptySetOpensTheKeypadInstead() async throws {
    let fixture = LiveFixture()
    let model = try await fixture.startedModel()
    let set = model.session.exercises[0].sets[0]
    #expect(set.proposed.weightKg == nil)
    await model.tap(set: set.id)
    #expect(model.session.exercises[0].sets[0].completedAt == nil)
    #expect(model.focus == field(model, set: 0, .weight))
    #expect(fixture.haptics.validation == 0)
    await model.keypadKey(.digit(6))
    await model.keypadKey(.digit(0))
    await model.tap(set: set.id)
    #expect(model.session.exercises[0].sets[0].weightKg == 60)
    #expect(model.session.exercises[0].sets[0].completedAt != nil)
}

@MainActor @Test func tappingASetWithoutRepsOpensTheRepsField() async throws {
    let fixture = LiveFixture()
    let model = try await fixture.startedModel()
    let exercise = model.session.exercises[0]
    model.focus(field(model, set: 0, .weight))
    await model.keypadKey(.digit(6))
    await model.keypadKey(.digit(0))
    model.focus(field(model, set: 0, .reps))
    await model.keypadKey(.digit(8))
    await model.keypadKey(.delete)
    await model.tap(set: exercise.sets[0].id)
    #expect(model.focus == field(model, set: 0, .reps))
    #expect(model.session.exercises[0].sets[0].completedAt == nil)
}

@MainActor @Test func setRPEAcceptsSixToTenByHalvesAndNil() async throws {
    let fixture = LiveFixture()
    try await fixture.seedBenchHistory()
    let model = try await fixture.startedModel()
    let set = model.session.exercises[0].sets[0].id
    await model.setRPE(8.5, set: set)
    #expect(model.session.exercises[0].sets[0].rpe == 8.5)
    #expect(!model.session.exercises[0].sets[0].isEdited)
    await model.setRPE(nil, set: set)
    #expect(model.session.exercises[0].sets[0].rpe == nil)
    await model.setRPE(5.5, set: set)
    await model.setRPE(8.3, set: set)
    #expect(model.session.exercises[0].sets[0].rpe == nil)
}

@MainActor @Test func structureActionsGoThroughTheService() async throws {
    let fixture = LiveFixture()
    try await fixture.seedBenchHistory()
    let model = try await fixture.startedModel()
    let exercise = model.session.exercises[0]
    await model.addSet(exercise: exercise.id)
    #expect(model.session.exercises[0].sets.count == exercise.sets.count + 1)
    await model.setType(.warmup, set: exercise.sets[0].id)
    #expect(model.session.exercises[0].sets[0].setType == .warmup)
    await model.deleteSet(exercise.sets[1].id)
    #expect(model.session.exercises[0].sets.count == exercise.sets.count)
    await model.setNote("Prise large", exercise: exercise.id)
    #expect(model.session.exercises[0].note == "Prise large")
    await model.setIncrement(1.25, exercise: exercise.id)
    #expect(model.session.exercises[0].incrementKg == 1.25)
    await model.moveExercise(exercise.id, by: 1)
    #expect(model.session.exercises.map(\.id).last == exercise.id)
    await model.removeExercise(exercise.id)
    #expect(model.session.exercises.count == 1)
    await model.addExercises([LiveFixture.plank])
    #expect(model.session.exercises.count == 2)
    #expect(model.session.exercises[1].exercise == LiveFixture.plank)
    let stored = await fixture.service.current()
    #expect(stored == model.session)
}

@MainActor @Test func restButtonsMoveTheEndAndSkipStops() async throws {
    let fixture = LiveFixture()
    try await fixture.seedBenchHistory()
    let model = try await fixture.startedModel()
    await model.tap(set: model.session.exercises[0].sets[0].id)
    let end = try #require(model.session.rest?.endsAt)
    await model.restPlus30()
    #expect(model.session.rest?.endsAt == end.addingTimeInterval(30))
    await model.restMinus30()
    #expect(model.session.rest?.endsAt == end)
    #expect(model.restRemaining(at: LiveClock.date("2026-11-02T08:01")) == 60)
    #expect(model.restRemaining(at: LiveClock.date("2026-11-02T08:02")) == nil)
    await model.skipRest()
    #expect(model.session.rest == nil)
    #expect(model.restRemaining(at: LiveClock.date("2026-11-02T08:01")) == nil)
}

@MainActor @Test func restEndVibratesOncePerRest() async throws {
    let fixture = LiveFixture()
    try await fixture.seedBenchHistory()
    let model = try await fixture.startedModel()
    model.didReachRestEnd()
    #expect(fixture.haptics.restEnded == 0)
    await model.tap(set: model.session.exercises[0].sets[0].id)
    model.didReachRestEnd()
    model.didReachRestEnd()
    #expect(fixture.haptics.restEnded == 1)
    fixture.clock.set("2026-11-02T08:03")
    await model.tap(set: model.session.exercises[0].sets[1].id)
    model.didReachRestEnd()
    #expect(fixture.haptics.restEnded == 2)
}

@MainActor @Test func restPlus30DoesNotVibrateAgainAfterTheEndWasReached() async throws {
    let fixture = LiveFixture()
    try await fixture.seedBenchHistory()
    let model = try await fixture.startedModel()
    await model.tap(set: model.session.exercises[0].sets[0].id)
    model.didReachRestEnd()
    await model.restPlus30()
    model.didReachRestEnd()
    #expect(fixture.haptics.restEnded == 1)
}

@MainActor @Test func aFailedChangeShowsAnErrorAndKeepsTheSession() async throws {
    let fixture = LiveFixture()
    let model = try await fixture.startedModel()
    let before = model.session
    _ = try await fixture.service.abandon(endedAt: LiveClock.date("2026-11-02T08:05"))
    await model.tap(set: before.exercises[0].sets[0].id)
    await model.addSet(exercise: before.exercises[0].id)
    #expect(model.errorMessage != nil)
    #expect(model.session == before)
}
