import Foundation
import PulseDomain
import Testing

@testable import PulseServices

/// La fin d'une course, la reprise d'un brouillon, le récap et la suppression.
@Suite(.timeLimit(.minutes(1)))
struct RunSessionFinishTests {
    private func trace(meters: Double) -> [RunTrackPoint] {
        RunTraceFactory.clean(meters: meters, speed: 3, start: RunSessionFixture.start)
    }

    // MARK: Fin

    @Test func finishSavesSessionTrackAndHealthWorkout() async throws {
        let fixture = RunSessionFixture()
        let launch = RunLaunch(title: "Sortie facile", programID: UUID(), routineDayID: UUID(), runType: .easy, targetMinutes: 30)
        let snapshot = try await fixture.service.start(launch)
        let points = trace(meters: 1_500)
        await fixture.push(Array(points[1...]))
        let recap = try await fixture.service.finish()

        let session = try #require(try await fixture.workouts.session(id: snapshot.sessionID))
        #expect(session == recap.session)
        #expect(session.source == .pulse)
        #expect(session.kind == .run)
        #expect(session.status == .completed)
        #expect(session.title == "Sortie facile")
        #expect(session.programID == launch.programID)
        #expect(session.routineDayID == launch.routineDayID)
        #expect(abs((session.distanceMeters ?? 0) - 1_500) / 1_500 < 0.01)
        #expect(abs((session.durationMinutes ?? 0) - 500.0 / 60) < 0.01)
        #expect(session.averageHeartRate == nil)
        #expect(session.estimatedRPE == nil)
        let entry = try #require(await fixture.recorder.finished.first)
        #expect(entry.sessionID == snapshot.sessionID)
        #expect(entry.distanceMeters == session.distanceMeters)
        #expect(session.healthKitUUID != nil)
        #expect(await fixture.recorder.hasLiveSession == false)

        let track = try #require(try await fixture.tracks.track(for: snapshot.sessionID))
        #expect(recap.track == track)
        #expect(track.points.count < entry.route.count)
        #expect(track.splits.map(\.kilometer) == [1, 2])
        #expect(track.elevationGainMeters != nil)
        #expect(try await fixture.drafts.load() == nil)
        #expect(await fixture.activity.endCount == 1)
        #expect(await fixture.reminders.calls.last == .cancel)
        #expect(await fixture.location.stopCount == 1)
        #expect(await fixture.service.current() == nil)
        await #expect(throws: RunSessionError.noRun) { try await fixture.service.finish() }
    }

    @Test func healthWriteFailureStillSavesTheRun() async throws {
        let fixture = RunSessionFixture(recorder: StubRunWorkoutRecorder(failsOnWrite: true))
        let snapshot = try await fixture.service.start(.free())
        await fixture.push(Array(trace(meters: 300)[1...]))
        let recap = try await fixture.service.finish()
        #expect(recap.session.healthKitUUID == nil)
        #expect(try await fixture.workouts.session(id: snapshot.sessionID) != nil)
        #expect(try await fixture.drafts.load() == nil)
    }

    @Test func failedSessionSaveDoesNotWriteHealthTwice() async throws {
        let workouts = CountingWorkoutRepository(failingAtSave: 1)
        let fixture = RunSessionFixture(workouts: workouts)
        let snapshot = try await fixture.service.start(.free())
        await fixture.push(Array(trace(meters: 300)[1...]))
        await #expect(throws: CountingWorkoutRepository.Failure.interrupted) { try await fixture.service.finish() }
        let draft = try #require(try await fixture.drafts.load())
        let healthID = try #require(draft.healthKitUUID)

        let offer = try #require(await fixture.service.recoveryOffer())
        #expect(!offer.isStillRecording)
        let recap = try await fixture.service.saveInterrupted()
        #expect(await fixture.recorder.finished.count == 1)
        #expect(await fixture.recorder.saved.isEmpty)
        #expect(recap.session.id == snapshot.sessionID)
        #expect(recap.session.healthKitUUID == healthID.uuidString)
        #expect(try await workouts.session(id: snapshot.sessionID)?.healthKitUUID == healthID.uuidString)
        #expect(try await fixture.drafts.load() == nil)
    }

    /// La séance HealthKit terminée par le système, ou qui échoue à la fin : l'entraînement est écrit sans elle, une fois.
    @Test(arguments: [false, true])
    func finishFallsBackToSaveWhenLiveSessionCannotFinish(finishThrows: Bool) async throws {
        let fixture = RunSessionFixture(recorder: StubRunWorkoutRecorder(failsOnFinish: finishThrows))
        let snapshot = try await fixture.service.start(.free())
        await fixture.push(Array(trace(meters: 300)[1...]))
        if !finishThrows { await fixture.recorder.loseLiveSession() }
        let recap = try await fixture.service.finish()
        #expect(await fixture.recorder.finished.isEmpty)
        let saved = await fixture.recorder.saved
        #expect(saved.count == 1)
        let workout = try #require(saved.first)
        #expect(workout.value.sessionID == snapshot.sessionID)
        #expect(recap.session.healthKitUUID == workout.key.uuidString)
        #expect(try await fixture.workouts.session(id: snapshot.sessionID)?.healthKitUUID == workout.key.uuidString)
    }

    @Test func deniedHealthWriteRunsWithoutHealthKit() async throws {
        let fixture = RunSessionFixture(recorder: StubRunWorkoutRecorder(access: .denied))
        _ = try await fixture.service.start(.free())
        await fixture.push(Array(trace(meters: 300)[1...]))
        let recap = try await fixture.service.finish()
        #expect(await fixture.recorder.started.isEmpty)
        #expect(await fixture.recorder.finished.isEmpty)
        #expect(recap.session.healthKitUUID == nil)
        #expect(recap.track != nil)
    }

    /// Sans séance HealthKit au départ, la course est enregistrée et son entraînement écrit à la fin, sans séance vivante.
    @Test func healthKitStartFailureStillRecordsTheRun() async throws {
        let fixture = RunSessionFixture(recorder: StubRunWorkoutRecorder(failsOnStart: true))
        _ = try await fixture.service.start(.free())
        await fixture.push(Array(trace(meters: 300)[1...]))
        let recap = try await fixture.service.finish()
        #expect(await fixture.recorder.saved.count == 1)
        #expect(recap.session.healthKitUUID != nil)
        #expect(abs((recap.session.distanceMeters ?? 0) - 300) / 300 < 0.02)
    }

    @Test func locationDeniedRecordsTimeOnly() async throws {
        let fixture = RunSessionFixture(location: StubRunLocationTracker(state: .denied))
        let snapshot = try await fixture.service.start(.free())
        #expect(snapshot.locationDenied)
        #expect(snapshot.distanceMeters == nil)
        #expect(await fixture.location.startCount == 0)
        fixture.advance(minutes: 25)
        #expect(await fixture.service.forgottenEnd() == nil)
        let recap = try await fixture.service.finish()
        #expect(recap.session.distanceMeters == nil)
        #expect((recap.session.durationMinutes ?? 0) > 0)
        #expect(recap.track == nil)
        #expect(try await fixture.tracks.track(for: snapshot.sessionID) == nil)
        #expect(await fixture.reminders.scheduled.isEmpty)
    }

    @Test func discardLeavesNothingBehind() async throws {
        let fixture = RunSessionFixture()
        let snapshot = try await fixture.service.start(.free())
        await fixture.push(Array(trace(meters: 60)[1...]))
        await fixture.service.discard()
        #expect(await fixture.service.current() == nil)
        #expect(try await fixture.drafts.load() == nil)
        #expect(try await fixture.workouts.session(id: snapshot.sessionID) == nil)
        #expect(await fixture.recorder.discardCount == 1)
        #expect(await fixture.activity.endCount == 1)
        #expect(await fixture.location.stopCount == 1)
        _ = try await fixture.service.start(.free())
    }

    // MARK: Reprise

    @Test func interruptedDraftIsOfferedWithReplayedDistance() async throws {
        let draft = RunSessionFixture.interruptedDraft(meters: 2_000)
        let fixture = RunSessionFixture(draft: draft)
        let offer = try #require(await fixture.service.recoveryOffer())
        #expect(offer.sessionID == draft.sessionID)
        #expect(abs((offer.distanceMeters ?? 0) - 2_000) / 2_000 < 0.01)
        #expect(!offer.isStillRecording)
        #expect(offer.lastPointAt == draft.points.last?.timestamp)
    }

    @Test func noDraftMeansNoOffer() async throws {
        let fixture = RunSessionFixture()
        #expect(await fixture.service.recoveryOffer() == nil)
        _ = try await fixture.service.start(.free())
        #expect(await fixture.service.recoveryOffer() == nil)
    }

    @Test func savingAnInterruptedRunWritesItWithoutLiveSession() async throws {
        let draft = RunSessionFixture.interruptedDraft(meters: 2_000)
        let fixture = RunSessionFixture(draft: draft)
        fixture.advance(minutes: 120)
        let recap = try await fixture.service.saveInterrupted()
        #expect(await fixture.recorder.finished.isEmpty)
        let entry = try #require(await fixture.recorder.saved.values.first)
        #expect(entry.end == draft.points.last?.timestamp)
        #expect(recap.session.id == draft.sessionID)
        #expect(recap.session.endedAt == draft.points.last?.timestamp)
        #expect(recap.session.healthKitUUID != nil)
        #expect(abs((recap.session.distanceMeters ?? 0) - 2_000) / 2_000 < 0.01)
        #expect(try await fixture.workouts.session(id: draft.sessionID) != nil)
        #expect(try await fixture.tracks.track(for: draft.sessionID) != nil)
        #expect(try await fixture.drafts.load() == nil)
        #expect(await fixture.activity.endAllCount == 1)
    }

    /// 1 km puis 20 min à piétiner, et le processus meurt : la course s'arrête au dernier déplacement, pas au dernier point, et
    /// sa durée ne compte pas l'arrêt.
    @Test func interruptedRunEndsAtLastMovement() async throws {
        let fixture = RunSessionFixture()
        let snapshot = try await fixture.service.start(.free())
        let points = Array(trace(meters: 1_000)[1...])
        await fixture.push(points)
        let lastMovement = try #require(RunTrackBuilder.replay(startedAt: fixture.start, points: points, pauses: []).lastMovementAt)
        let last = try #require(points.last)
        await fixture.push(RunTraceFactory.standing(after: last, count: 120, every: 10))

        // Le processus meurt ; au lancement suivant, la séance HealthKit n'est pas récupérée.
        let recorder = StubRunWorkoutRecorder()
        let relaunched = fixture.relaunched(recorder: recorder)
        let offer = try #require(await relaunched.recoveryOffer())
        #expect(offer.lastPointAt == lastMovement)
        let recap = try await relaunched.saveInterrupted()
        #expect(recap.session.id == snapshot.sessionID)
        #expect(recap.session.endedAt == lastMovement)
        let minutes = try #require(recap.session.durationMinutes)
        #expect(abs(minutes - lastMovement.timeIntervalSince(fixture.start) / 60) < 0.001)
        #expect(abs((recap.session.distanceMeters ?? 0) - 1_000) / 1_000 < 0.01)
        #expect(try #require(await recorder.saved.values.first).end == lastMovement)
    }

    /// Une séance HealthKit rattachée au lancement, sans que la course reprenne : « Enregistrer » la termine avant d'écrire.
    @Test func saveInterruptedDiscardsARecoveredSession() async throws {
        let draft = RunSessionFixture.interruptedDraft(meters: 2_000)
        let fixture = RunSessionFixture(recorder: StubRunWorkoutRecorder(recoverable: true), draft: draft)
        let offer = try #require(await fixture.service.recoveryOffer())
        #expect(offer.isStillRecording)
        let recap = try await fixture.service.saveInterrupted()
        #expect(await fixture.recorder.discardCount == 1)
        #expect(await fixture.recorder.hasLiveSession == false)
        #expect(await fixture.recorder.saved.count == 1)
        #expect(recap.session.healthKitUUID != nil)
    }

    /// Un brouillon revenu après l'enregistrement de sa course : il est vidé, sans rien proposer ni écrire une seconde fois.
    @Test func draftOfAnAlreadySavedRunIsCleared() async throws {
        let draft = RunSessionFixture.interruptedDraft(meters: 500)
        let fixture = RunSessionFixture(draft: draft)
        _ = try await fixture.service.saveInterrupted()

        try await fixture.drafts.save(draft)
        #expect(await fixture.service.recoveryOffer() == nil)
        #expect(try await fixture.drafts.load() == nil)

        try await fixture.drafts.save(draft)
        await #expect(throws: RunSessionError.noRun) { try await fixture.service.saveInterrupted() }
        #expect(try await fixture.drafts.load() == nil)
        #expect(await fixture.recorder.saved.count == 1)
    }

    @Test func recoveredLiveSessionReattaches() async throws {
        let draft = RunSessionFixture.interruptedDraft(meters: 2_000)
        let fixture = RunSessionFixture(recorder: StubRunWorkoutRecorder(recoverable: true), draft: draft)
        let offer = try #require(await fixture.service.recoveryOffer())
        #expect(offer.isStillRecording)
        let snapshot = try #require(await fixture.service.reattach())
        #expect(snapshot.sessionID == draft.sessionID)
        #expect(abs((snapshot.distanceMeters ?? 0) - 2_000) / 2_000 < 0.01)
        #expect(await fixture.location.startCount == 1)
        #expect(await fixture.service.current()?.sessionID == draft.sessionID)

        // La course reprend là où le brouillon s'arrêtait.
        let more = RunTraceFactory.clean(meters: 2_300, speed: 3, start: fixture.start).suffix(from: draft.points.count)
        await fixture.push(Array(more))
        let recap = try await fixture.service.finish()
        #expect(abs((recap.session.distanceMeters ?? 0) - 2_300) / 2_300 < 0.01)
        #expect(await fixture.recorder.finished.count == 1)
    }

    // MARK: Récap et suppression

    @Test func completeRecapStoresRPEAndNote() async throws {
        let fixture = RunSessionFixture()
        _ = try await fixture.service.start(.free())
        await fixture.push(Array(trace(meters: 300)[1...]))
        let recap = try await fixture.service.finish()
        try await fixture.service.completeRecap(sessionID: recap.session.id, rpe: 7, note: "Jambes lourdes")
        var stored = try #require(try await fixture.workouts.session(id: recap.session.id))
        #expect(stored.overallRPE == 7)
        #expect(stored.note == "Jambes lourdes")
        #expect(stored.distanceMeters == recap.session.distanceMeters)

        try await fixture.service.completeRecap(sessionID: recap.session.id, rpe: nil, note: "  ")
        stored = try #require(try await fixture.workouts.session(id: recap.session.id))
        #expect(stored.overallRPE == nil)
        #expect(stored.note == nil)
        await #expect(throws: RunSessionError.noRun) {
            try await fixture.service.completeRecap(sessionID: UUID(), rpe: 5, note: nil)
        }
    }

    @Test func deleteRunRemovesSessionTrackAndHealthWorkout() async throws {
        let fixture = RunSessionFixture()
        _ = try await fixture.service.start(.free())
        await fixture.push(Array(trace(meters: 300)[1...]))
        let recap = try await fixture.service.finish()
        let healthID = try #require(recap.session.healthKitUUID.flatMap(UUID.init(uuidString:)))
        try await fixture.service.deleteRun(sessionID: recap.session.id)
        #expect(try await fixture.workouts.session(id: recap.session.id) == nil)
        #expect(try await fixture.tracks.track(for: recap.session.id) == nil)
        #expect(await fixture.recorder.deletedWorkouts == [healthID])
        #expect(await fixture.recorder.deletedRunWorkouts.isEmpty)
    }
}
