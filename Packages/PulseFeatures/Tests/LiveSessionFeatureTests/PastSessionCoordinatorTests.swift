import Foundation
@testable import LiveSessionFeature
import PulseDomain
import PulseServices
import Testing

/// La saisie d'une séance passée (spec M4 §19.4) : le même écran et le même récap, sur le service des séances passées.
@MainActor
struct PastSessionCoordinatorTests {
    private let fixture = LiveFixture()
    /// Le mercredi 28 octobre 2026 de 18 h à 19 h 05.
    private let interval = DateInterval(start: LiveClock.date("2026-10-28T18:00"), end: LiveClock.date("2026-10-28T19:05"))

    private var pastLaunch: SessionLaunch {
        SessionLaunch.past(LiveFixture.pushLaunch.day, programID: nil, interval: interval)
    }

    private func pastCoordinator() -> PastSessionCoordinator {
        let train = fixture.environment.train
        var environment = fixture.environment
        environment.service = ActiveSessionService.pastSessions(
            workouts: train.workouts, profiles: train.profiles, settings: train.exerciseSettings,
            userExercises: train.userExercises, records: train.records, library: train.library, calendar: train.calendar,
            now: train.now)
        return PastSessionCoordinator(environment: environment)
    }

    @Test func finishingSavesTheSessionAtItsEnteredEnd() async throws {
        try await fixture.seedBenchHistory()
        let coordinator = pastCoordinator()
        await coordinator.start(pastLaunch)
        #expect(coordinator.isPresented && coordinator.errorMessage == nil)
        let model = coordinator.model()
        #expect(model.session.isPastEntry && model.session.startedAt == interval.start)
        let firstSet = try #require(model.session.exercises.first?.sets.first)
        await model.tap(set: firstSet.id)
        #expect(model.session.rest == nil)

        let flow = coordinator.finishFlow()
        await flow.finishTapped()
        #expect(flow.forgotten == nil)
        await flow.confirm()?.value
        let recap = try #require(flow.recap)
        #expect(recap.recap?.endedAt == interval.end && recap.recap?.durationMinutes == 65)
        #expect(await recap.save())
        flow.recapSaved()
        #expect(!coordinator.isPresented)

        let saved = try await fixture.workouts.sessions(from: interval.start, to: interval.end)
        #expect(saved.count == 1 && saved.first?.endedAt == interval.end && saved.first?.status == .completed)
        // La séance en direct n'a rien vu : ni snapshot, ni notification, ni Live Activity.
        #expect(await fixture.service.current() == nil)
        #expect(await fixture.activity.states.isEmpty)
        #expect(await fixture.notifier.scheduled.isEmpty)
    }

    @Test func cancellingTheEntrySavesNothing() async throws {
        let coordinator = pastCoordinator()
        await coordinator.start(pastLaunch)
        let model = coordinator.model()
        let firstSet = try #require(model.session.exercises.first?.sets.first)
        await model.tap(set: firstSet.id)
        let flow = coordinator.finishFlow()
        flow.abandonTapped()
        #expect(flow.confirmation == .abandon)
        await flow.confirm()?.value
        #expect(!coordinator.isPresented)
        #expect(try await fixture.workouts.sessions(from: .distantPast, to: .distantFuture).isEmpty)
    }

    @Test func aLiveLaunchIsNotAPastEntry() async {
        let coordinator = pastCoordinator()
        await coordinator.start(LiveFixture.pushLaunch)
        #expect(!coordinator.isPresented)
    }

    @Test func theHeaderSaysTheDateAndTheEnteredDuration() {
        #expect(LiveHeader.pastDateText(start: interval.start, end: interval.end, calendar: LiveClock.calendar)
            == "Mercredi 28 octobre · 18:00 – 19:05")
        #expect(LiveHeader.pastDateSpokenText(start: interval.start, end: interval.end, calendar: LiveClock.calendar)
            == "Mercredi 28 octobre, de 18 heures à 19 heures 5")
        #expect(LiveHeader.minutes(from: interval.start, to: interval.end) == 65)
    }
}
