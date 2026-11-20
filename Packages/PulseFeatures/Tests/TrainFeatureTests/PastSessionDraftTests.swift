import Foundation
import PulseDomain
import PulseServices
import Testing
@testable import TrainFeature

/// Le formulaire de « Saisir une séance passée » (spec M4 §19.4). L'horloge est le lundi 2 novembre 2026 à 9 h.
struct PastSessionDraftTests {
    private let calendar = TrainClock.calendar
    private let now = TrainClock.date(day: 2, hour: 9)

    @Test func theInitialDraftEndsAtTheLastFullHour() throws {
        let draft = PastSessionDraft.initial(now: now.addingTimeInterval(10 * 60), calendar: calendar)
        let interval = try #require(draft.interval(now: now.addingTimeInterval(10 * 60), calendar: calendar))
        #expect(interval.start == TrainClock.date(day: 2, hour: 8) && interval.end == now)
        #expect(draft.routineID == nil)
    }

    @Test func theStartCombinesTheDayWithTheStartTime() throws {
        let draft = PastSessionDraft(day: TrainClock.date(month: 10, day: 28, hour: 0),
                                     startTime: TrainClock.date(day: 1, hour: 18), durationMinutes: 65)
        let interval = try #require(draft.interval(now: now, calendar: calendar))
        #expect(interval.start == TrainClock.date(month: 10, day: 28, hour: 18))
        #expect(interval.duration == 65 * 60)
    }

    @Test func aSessionNotFinishedYetCannotBeEntered() {
        let future = PastSessionDraft(day: now, startTime: TrainClock.date(day: 2, hour: 10), durationMinutes: 60)
        #expect(future.problem(now: now, calendar: calendar) == "L'heure de début doit être passée.")
        let unfinished = PastSessionDraft(day: now, startTime: TrainClock.date(day: 2, hour: 8), durationMinutes: 90)
        #expect(unfinished.problem(now: now, calendar: calendar)?.hasPrefix("La séance doit être finie") == true)
        #expect(unfinished.interval(now: now, calendar: calendar) == nil)
    }

    @MainActor @Test func aPastLaunchTakesTheChosenRoutineAsPlanned() async throws {
        let fixture = TrainFixture()
        let program = pplProgram()
        try await fixture.activate(program)
        try await fixture.scoreToday(.moderateFatigue)
        let model = TrainModel(environment: fixture.environment)
        await model.refresh()
        let push = try #require(program.days.first { $0.name == "Push" })
        var draft = PastSessionDraft(day: TrainClock.date(month: 10, day: 29, hour: 0),
                                     startTime: TrainClock.date(day: 2, hour: 18), durationMinutes: 60, routineID: push.id)
        let launch = try #require(model.pastLaunch(draft))
        // Le score d'aujourd'hui n'ajuste pas une séance d'un autre jour.
        #expect(launch.day == push && launch.applied.isEmpty && launch.policy.allowsIncrease)
        #expect(launch.programID == program.id && launch.title == "Push")
        #expect(launch.past?.start == TrainClock.date(month: 10, day: 29, hour: 18))

        draft.routineID = nil
        let empty = try #require(model.pastLaunch(draft))
        #expect(empty.day == nil && empty.programID == nil && empty.title == "Séance libre")
    }
}
