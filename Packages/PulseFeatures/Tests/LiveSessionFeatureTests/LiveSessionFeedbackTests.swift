import Foundation
@testable import LiveSessionFeature
import PulseDomain
import PulseServices
import Testing

// Les retours de la séance : vibrations de fin d'exercice et de séance, compte à rebours du repos, ajout et suppression, et
// la progression que l'écran affiche.

@MainActor @Test func finishingAnExerciseAddsTheSuccessHapticOnce() async throws {
    let fixture = LiveFixture()
    try await fixture.seedBenchHistory()
    let model = try await fixture.startedModel()
    let sets = model.session.exercises[0].sets.map(\.id)
    await model.tap(set: sets[0])
    await model.tap(set: sets[1])
    #expect(fixture.haptics.exerciseDone == 0)
    #expect(!model.session.exercises[0].isDone)
    await model.tap(set: sets[2])
    #expect(model.session.exercises[0].isDone)
    #expect(model.session.exercises[0].doneSetCount == 3)
    #expect(fixture.haptics.validation == 3)
    #expect(fixture.haptics.exerciseDone == 1)
    #expect(fixture.haptics.sessionDone == 0)
    // Dévalider est un pas en arrière : vibration molle, l'exercice n'est plus fini.
    await model.tap(set: sets[2])
    #expect(fixture.haptics.soft == 1)
    #expect(!model.session.exercises[0].isDone)
    await model.tap(set: sets[2])
    #expect(fixture.haptics.exerciseDone == 2)
}

@MainActor @Test func finishingTheLastSetCelebratesTheSession() async throws {
    let fixture = LiveFixture()
    let model = try await fixture.startedModel(LiveFixture.plankLaunch)
    let exercise = model.session.exercises[0]
    let kind: KeypadField.Kind = exercise.tracksDuration ? .duration : .reps
    for set in exercise.sets {
        model.focus(KeypadField(exercise: exercise.id, set: set.id, kind: kind))
        await model.keypadKey(.digit(3))
        await model.keypadKey(.digit(0))
        await model.tap(set: set.id)
    }
    #expect(model.session.isDone)
    #expect(fixture.haptics.sessionDone == 1)
    // La fin de la séance remplace celle de l'exercice : une seule fête.
    #expect(fixture.haptics.exerciseDone == 0)
}

@MainActor @Test func restCountdownTicksOnceForEachOfTheLastThreeSeconds() async throws {
    let fixture = LiveFixture()
    try await fixture.seedBenchHistory()
    let model = try await fixture.startedModel()
    model.restCountdown(secondsLeft: 2)
    #expect(fixture.haptics.tick == 0)
    await model.tap(set: model.session.exercises[0].sets[0].id)
    model.restCountdown(secondsLeft: 5)
    model.restCountdown(secondsLeft: 4)
    #expect(fixture.haptics.tick == 0)
    model.restCountdown(secondsLeft: 3)
    model.restCountdown(secondsLeft: 3)
    model.restCountdown(secondsLeft: 2)
    model.restCountdown(secondsLeft: 1)
    model.restCountdown(secondsLeft: 0)
    #expect(fixture.haptics.tick == 3)
    // Fin atteinte : +30 s relance le repos sans refaire le compte à rebours de ce repos-là.
    model.didReachRestEnd()
    model.restCountdown(secondsLeft: 1)
    #expect(fixture.haptics.tick == 3)
}

@MainActor @Test func addingASetTicksAndDeletingOneIsSoft() async throws {
    let fixture = LiveFixture()
    try await fixture.seedBenchHistory()
    let model = try await fixture.startedModel()
    let exercise = model.session.exercises[0].id
    await model.addSet(exercise: exercise)
    #expect(model.session.exercises[0].sets.count == 4)
    #expect(fixture.haptics.tick == 1)
    await model.deleteSet(model.session.exercises[0].sets[3].id)
    #expect(model.session.exercises[0].sets.count == 3)
    #expect(fixture.haptics.soft == 1)
}

@MainActor @Test func theUpcomingSetFollowsTheLastValidatedOne() async throws {
    let fixture = LiveFixture()
    try await fixture.seedBenchHistory()
    let model = try await fixture.startedModel()
    let sets = model.session.exercises[0].sets.map(\.id)
    #expect(model.session.upcomingSetID == sets[0])
    await model.tap(set: sets[0])
    #expect(model.session.upcomingSetID == sets[1])
    #expect(!model.session.isDone)
}

@Test func sessionProgressFractionStaysBetweenZeroAndOne() {
    #expect(SessionProgressBar.fraction(done: 0, planned: 0) == 0)
    #expect(SessionProgressBar.fraction(done: 3, planned: 12) == 0.25)
    #expect(SessionProgressBar.fraction(done: 14, planned: 12) == 1)
}

@Test func restBannerCountsSecondsUpAndFlagsTheLastFive() {
    let start = LiveClock.date("2026-11-02T08:00")
    let rest = LiveRest(startedAt: start, endsAt: start.addingTimeInterval(90), exerciseID: UUID())
    #expect(RestBanner.secondsLeft(of: rest, at: start.addingTimeInterval(84.2)) == 6)
    #expect(!RestBanner.isEnding(rest, at: start.addingTimeInterval(84.2)))
    #expect(RestBanner.isEnding(rest, at: start.addingTimeInterval(85.5)))
    #expect(!RestBanner.isEnding(rest, at: start.addingTimeInterval(90)))
}

@Test func exerciseRingSaysWhenTheExerciseIsDone() {
    #expect(LiveExerciseCard.progressSpokenText(done: 2, total: 5) == "2 séries faites sur 5")
    #expect(LiveExerciseCard.progressSpokenText(done: 1, total: 3) == "1 série faite sur 3")
    #expect(LiveExerciseCard.progressSpokenText(done: 3, total: 3) == "Exercice terminé")
}
