import Foundation
import PulseDomain
import Testing

@testable import PulseServices

@Suite(.timeLimit(.minutes(1)))
struct RunSessionServiceTests {
    private func trace(meters: Double) -> [RunTrackPoint] {
        RunTraceFactory.clean(meters: meters, speed: 3, start: RunSessionFixture.start)
    }

    // MARK: Départ

    @Test func startWritesADraftAndStartsEverything() async throws {
        let fixture = RunSessionFixture()
        let snapshot = try await fixture.service.start(.free())
        let draft = try #require(try await fixture.drafts.load())
        #expect(draft.sessionID == snapshot.sessionID)
        #expect(draft.startedAt == fixture.start)
        #expect(await fixture.recorder.started.map(\.sessionID) == [snapshot.sessionID])
        #expect(await fixture.location.startCount == 1)
        #expect(await fixture.activity.states.map(\.sessionID) == [snapshot.sessionID])
        #expect(snapshot.distanceMeters == 0)
        #expect(snapshot.gps == .searching)
        #expect(!snapshot.locationDenied)
        #expect(await fixture.service.current() == snapshot)
    }

    @Test func secondStartIsRefused() async throws {
        let fixture = RunSessionFixture()
        _ = try await fixture.service.start(.free())
        await #expect(throws: RunSessionError.alreadyRunning) { try await fixture.service.start(.free()) }

        // Un brouillon laissé par un lancement précédent bloque aussi le départ.
        let relaunched = RunSessionFixture(draft: RunSessionFixture.interruptedDraft(meters: 500))
        await #expect(throws: RunSessionError.alreadyRunning) { try await relaunched.service.start(.free()) }
        #expect(await relaunched.recorder.started.isEmpty)
    }

    @Test func authorizationsAreAskedOnlyWhenUndetermined() async throws {
        let fixture = RunSessionFixture(
            recorder: StubRunWorkoutRecorder(access: .notDetermined),
            location: StubRunLocationTracker(state: .notDetermined))
        _ = try await fixture.service.start(.free())
        #expect(await fixture.location.requestCount == 1)
        #expect(await fixture.recorder.requestCount == 1)

        let granted = RunSessionFixture()
        _ = try await granted.service.start(.free())
        #expect(await granted.location.requestCount == 0)
        #expect(await granted.recorder.requestCount == 0)
    }

    @Test func previewReportsReadyUnderTwentyMetres() async throws {
        let fixture = RunSessionFixture()
        let qualities = await fixture.service.gpsPreview()
        let start = fixture.start
        await fixture.location.push(RunTraceFactory.point(northMeters: 0, second: 0, start: start, accuracy: 40))
        await fixture.location.push(RunTraceFactory.point(northMeters: 0, second: 1, start: start, accuracy: 38))
        await fixture.location.push(RunTraceFactory.point(northMeters: 0, second: 2, start: start, accuracy: 15))
        var iterator = qualities.makeAsyncIterator()
        var received: [RunGPSQuality] = []
        for _ in 0..<3 {
            if let quality = await iterator.next() { received.append(quality) }
        }
        #expect(received == [.searching, .weak, .ready])
        await fixture.service.cancelPreview()
        #expect(await iterator.next() == nil)
        #expect(await fixture.location.stopCount == 1)
    }

    @Test func previewEndsAtOnceWhenLocationIsDenied() async {
        let fixture = RunSessionFixture(location: StubRunLocationTracker(state: .denied))
        var iterator = await fixture.service.gpsPreview().makeAsyncIterator()
        #expect(await iterator.next() == nil)
        #expect(await fixture.location.startCount == 0)
    }

    /// Une course partie pendant que l'aperçu attendait l'autorisation : l'aperçu se termine sans relancer la localisation, et le
    /// flux de points de la course reste le sien.
    @Test func previewDoesNotReplaceARunStartedMeanwhile() async throws {
        let tracker = GatedRunLocationTracker()
        let service = RunSessionService(
            recorder: StubRunWorkoutRecorder(), location: tracker, announcer: StubRunAnnouncer(),
            activity: StubRunActivityController(), reminders: StubRunReminderScheduler(), drafts: InMemoryRunDraftStore(),
            workouts: InMemoryWorkoutRepository(), tracks: InMemoryRunTrackRepository(), profiles: InMemoryProfileRepository(),
            preferences: InMemoryRunPreferencesStore(), spokenText: RunSessionFixture.spokenText,
            now: { RunSessionFixture.start }, calendar: TestClock.calendar, keepAliveTicks: { _ in AsyncStream { $0.finish() } })
        let preview = Task { await service.gpsPreview() }
        await tracker.gate.waitForArrival()
        _ = try await service.start(.free())
        await tracker.gate.open()

        var iterator = await preview.value.makeAsyncIterator()
        try #require(await iterator.next() == nil)
        #expect(await tracker.inner.startCount == 1)
        await tracker.inner.push(RunTraceFactory.point(northMeters: 0, second: 1, start: RunSessionFixture.start))
        await service.waitUntilHandled(points: 1)
        #expect(await service.current()?.gps == .ready)
    }

    // MARK: Localisation laissée allumée (flèche de localisation hors course)

    /// L'aperçu du départ ne garde pas la localisation en arrière-plan ; la course, si.
    @Test func onlyTheRunKeepsLocationInTheBackground() async throws {
        let fixture = RunSessionFixture()
        _ = await fixture.service.gpsPreview()
        _ = try await fixture.service.start(.free())
        #expect(await fixture.location.backgroundStarts == [false, true])
        _ = try await fixture.service.finish()
        #expect(await fixture.location.stopCount == 2)
    }

    /// L'écran de départ fermé pendant que l'aperçu attendait l'autorisation : la localisation ne démarre pas après coup.
    @Test func previewCancelledWhileAuthorizingNeverStartsLocation() async throws {
        let tracker = GatedRunLocationTracker()
        let service = RunSessionService(
            recorder: StubRunWorkoutRecorder(), location: tracker, announcer: StubRunAnnouncer(),
            activity: StubRunActivityController(), reminders: StubRunReminderScheduler(), drafts: InMemoryRunDraftStore(),
            workouts: InMemoryWorkoutRepository(), tracks: InMemoryRunTrackRepository(), profiles: InMemoryProfileRepository(),
            preferences: InMemoryRunPreferencesStore(), spokenText: RunSessionFixture.spokenText,
            now: { RunSessionFixture.start }, calendar: TestClock.calendar, keepAliveTicks: { _ in AsyncStream { $0.finish() } })
        let preview = Task { await service.gpsPreview() }
        await tracker.gate.waitForArrival()
        await service.cancelPreview()
        await tracker.gate.open()

        var iterator = await preview.value.makeAsyncIterator()
        #expect(await iterator.next() == nil)
        #expect(await tracker.inner.startCount == 0)
    }

    /// Une course rattachée pendant que l'écran de départ suivait le signal : l'aperçu lâche la localisation, et sa fermeture
    /// n'arrête pas celle de la course.
    @Test func reattachTakesOverThePreviewLocation() async throws {
        let draft = RunSessionFixture.interruptedDraft(meters: 500)
        let fixture = RunSessionFixture(recorder: StubRunWorkoutRecorder(recoverable: true), draft: draft)
        _ = await fixture.service.gpsPreview()
        #expect(await fixture.service.reattach() != nil)
        #expect(await fixture.location.backgroundStarts == [false, true])
        let stops = await fixture.location.stopCount
        await fixture.service.cancelPreview()
        #expect(await fixture.location.stopCount == stops)
        await fixture.service.discard()
        #expect(await fixture.location.stopCount == stops + 1)
    }

    // MARK: Annonces, brouillon et Live Activity

    @Test func kilometreIsAnnouncedOnce() async throws {
        let fixture = RunSessionFixture()
        _ = try await fixture.service.start(.free())
        await fixture.push(trace(meters: 1_200))
        let announcements = await fixture.announcer.announcements
        #expect(announcements.count == 1)
        #expect(announcements.first?.hasPrefix("km 1 ") == true)
        let snapshot = try #require(await fixture.service.current())
        #expect(abs((snapshot.distanceMeters ?? 0) - 1_200) / 1_200 < 0.01)
        #expect(snapshot.gps == .ready)
        #expect(snapshot.averagePace != nil)
    }

    @Test func targetMilestonesAreAnnounced() async throws {
        let fixture = RunSessionFixture()
        _ = try await fixture.service.start(RunLaunch(title: "Sortie facile", runType: .easy, targetKm: 1))
        await fixture.push(trace(meters: 1_100))
        let announcements = await fixture.announcer.announcements
        #expect(announcements.count == 3)
        #expect(announcements.first == "mi-objectif")
        #expect(announcements.dropFirst().first?.hasPrefix("km 1 ") == true)
        #expect(announcements.last == "objectif atteint")
    }

    @Test func announcementsCanBeTurnedOff() async throws {
        let fixture = RunSessionFixture()
        fixture.preferences.setAnnouncesKilometres(false)
        _ = try await fixture.service.start(.free())
        await fixture.push(trace(meters: 1_200))
        #expect(await fixture.announcer.announcements.isEmpty)
    }

    @Test func draftIsWrittenEveryTenSeconds() async throws {
        let fixture = RunSessionFixture()
        _ = try await fixture.service.start(.free())
        await fixture.push(Array(trace(meters: 75)[1...25]))
        #expect(await fixture.drafts.saveCount == 3)
        let draft = try #require(try await fixture.drafts.load())
        #expect(draft.points.count == 20)
    }

    @Test func pauseAndResumeWriteTheDraftAtOnce() async throws {
        let fixture = RunSessionFixture()
        _ = try await fixture.service.start(.free())
        await fixture.push(Array(trace(meters: 9)[1...2]))
        await fixture.service.pause()
        var draft = try #require(try await fixture.drafts.load())
        #expect(draft.pauses.count == 1)
        #expect(draft.pauses.first?.end == nil)
        fixture.advance(minutes: 2)
        await fixture.service.resume()
        draft = try #require(try await fixture.drafts.load())
        #expect(draft.pauses.first?.end == fixture.clock.now)
        #expect(await fixture.drafts.saveCount == 3)
        #expect(await fixture.recorder.pauseDates.count == 1)
        #expect(await fixture.recorder.resumeDates == [fixture.clock.now])
        let states = await fixture.activity.states
        #expect(states.map(\.isPaused) == [false, true, false])
        #expect(states[1].timerStart == nil)
        #expect(states[2].timerStart == fixture.clock.now.addingTimeInterval(-2))
    }

    @Test func activityIsNotUpdatedEverySecond() async throws {
        let fixture = RunSessionFixture()
        _ = try await fixture.service.start(.free())
        await fixture.push(Array(trace(meters: 180)[1...60]))
        let updates = await fixture.activity.states.count - 1
        #expect(updates >= 1)
        #expect(updates <= 4)
    }

    @Test func activityIsUpdatedAtEachKilometre() async throws {
        let fixture = RunSessionFixture()
        _ = try await fixture.service.start(.free())
        let points = trace(meters: 1_020)
        await fixture.push(Array(points[1...]))
        let states = await fixture.activity.states
        #expect(states.contains { ($0.distanceMeters ?? 0) >= 1_000 && ($0.distanceMeters ?? 0) < 1_010 })
    }

    @Test func heartRateIsShownAndAveraged() async throws {
        let fixture = RunSessionFixture()
        _ = try await fixture.service.start(.free())
        await fixture.pushHeartRate(140)
        await fixture.pushHeartRate(160)
        #expect(await fixture.service.current()?.heartRate == 160)
        fixture.advance(minutes: 20)
        let recap = try await fixture.service.finish()
        #expect(recap.session.averageHeartRate == 150)
        // 150 / 190 = 79 % de la FC max par défaut : RPE 7.
        #expect(recap.session.estimatedRPE == 7)
        let stored = try #require(try await fixture.workouts.session(id: recap.session.id))
        #expect(stored.averageHeartRate == 150)
    }

    // MARK: Oubli

    @Test func pausedRunNeverSchedulesForgottenReminder() async throws {
        let fixture = RunSessionFixture()
        _ = try await fixture.service.start(.free())
        let points = trace(meters: 300)
        await fixture.push(Array(points[1...]))
        await fixture.service.pause()
        let last = try #require(points.last)
        await fixture.push(RunTraceFactory.standing(after: last, count: 240, every: 10))
        #expect(await fixture.reminders.calls.last == .cancel)
        #expect(await fixture.service.forgottenEnd() == nil)
    }

    @Test func standingStillForThirtyMinutesOffersTheLastMovement() async throws {
        let fixture = RunSessionFixture()
        _ = try await fixture.service.start(.free())
        let points = Array(trace(meters: 1_000)[1...])
        await fixture.push(points)
        let lastMovement = try #require(RunTrackBuilder.replay(startedAt: fixture.start, points: points, pauses: []).lastMovementAt)
        #expect(await fixture.service.forgottenEnd() == nil)
        let last = try #require(points.last)
        await fixture.push(RunTraceFactory.standing(after: last, count: 186, every: 10))
        let end = try #require(await fixture.service.forgottenEnd())
        #expect(end == lastMovement)
        let scheduled = try #require(await fixture.reminders.scheduled.last)
        #expect(scheduled.timeIntervalSince(lastMovement) <= RunSessionService.forgottenAfter)
        #expect(scheduled.timeIntervalSince(lastMovement) > RunSessionService.forgottenAfter - 61)

        let recap = try await fixture.service.finish(at: end)
        #expect(recap.session.endedAt == end)
        let minutes = try #require(recap.session.durationMinutes)
        #expect(abs(minutes - end.timeIntervalSince(fixture.start) / 60) < 0.001)
        #expect(abs((recap.session.distanceMeters ?? 0) - 1_000) / 1_000 < 0.01)
    }

    @Test func resumeDoesNotOfferAnEndRightAway() async throws {
        let fixture = RunSessionFixture()
        _ = try await fixture.service.start(.free())
        await fixture.push(Array(trace(meters: 300)[1...]))
        await fixture.service.pause()
        fixture.advance(minutes: 45)
        await fixture.service.resume()
        #expect(await fixture.service.forgottenEnd() == nil)
        #expect(await fixture.reminders.calls.last == .schedule(fixture.clock.now.addingTimeInterval(RunSessionService.forgottenAfter)))
        fixture.advance(minutes: 31)
        #expect(await fixture.service.forgottenEnd() == fixture.clock.now.addingTimeInterval(-31 * 60))
    }
}

/// Une localisation dont la première lecture de l'autorisation attend devant une porte, pour rejouer un départ pendant l'aperçu.
private actor GatedRunLocationTracker: RunLocationTracking {
    let inner = StubRunLocationTracker()
    let gate = Gate()
    private var isHolding = true

    func authorization() async -> RunLocationAuthorization {
        if isHolding {
            isHolding = false
            await gate.pass()
        }
        return await inner.authorization()
    }

    func requestAuthorization() async -> RunLocationAuthorization {
        await inner.requestAuthorization()
    }

    func isAccuracyReduced() async -> Bool {
        await inner.isAccuracyReduced()
    }

    func start(keepsRunningInBackground: Bool) async -> AsyncStream<RunTrackPoint> {
        await inner.start(keepsRunningInBackground: keepsRunningInBackground)
    }

    func stop() async {
        await inner.stop()
    }
}
