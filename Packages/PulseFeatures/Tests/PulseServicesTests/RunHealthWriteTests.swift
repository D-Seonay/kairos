import Foundation
import PulseDomain
import Testing

@testable import PulseServices

/// L'entraînement de la course n'est jamais écrit deux fois dans Apple Santé, même quand HealthKit le garde pour l'écrire au
/// déverrouillage de l'iPhone.
@Suite(.timeLimit(.minutes(1)))
struct RunHealthWriteTests {
    private func trace(meters: Double) -> [RunTrackPoint] {
        RunTraceFactory.clean(meters: meters, speed: 3, start: RunSessionFixture.start)
    }

    /// iPhone verrouillé à la fin : HealthKit garde l'entraînement de la séance, le repli ne l'écrit pas une seconde fois.
    @Test func deferredFinishIsNotWrittenAgainByTheFallback() async throws {
        let fixture = RunSessionFixture(recorder: StubRunWorkoutRecorder(defersWrite: true))
        let snapshot = try await fixture.service.start(.free())
        await fixture.push(Array(trace(meters: 300)[1...]))
        let recap = try await fixture.service.finish()
        #expect(await fixture.recorder.deferred.count == 1)
        #expect(await fixture.recorder.saved.isEmpty)
        #expect(await fixture.recorder.finished.isEmpty)
        #expect(recap.session.healthKitUUID == nil)
        #expect(try await fixture.workouts.session(id: snapshot.sessionID) != nil)
        #expect(try await fixture.drafts.load() == nil)
    }

    /// La course dont l'entraînement a été écrit au déverrouillage, sans identifiant connu : la supprimer le cherche par
    /// l'identifiant de la course pour le supprimer aussi.
    @Test func deletingADeferredRunRemovesItsWorkoutByRunID() async throws {
        let fixture = RunSessionFixture(recorder: StubRunWorkoutRecorder(defersWrite: true))
        let snapshot = try await fixture.service.start(.free())
        await fixture.push(Array(trace(meters: 300)[1...]))
        _ = try await fixture.service.finish()
        try await fixture.service.deleteRun(sessionID: snapshot.sessionID)
        #expect(await fixture.recorder.deletedRunWorkouts == [snapshot.sessionID])
        #expect(await fixture.recorder.deferred.isEmpty)
        #expect(await fixture.recorder.deletedWorkouts.isEmpty)
    }

    /// Fin laissée à HealthKit, puis l'enregistrement dans Pulse échoue : « Enregistrer » de la reprise n'écrit rien dans Santé.
    @Test func deferredFinishIsRememberedForTheRecovery() async throws {
        let workouts = CountingWorkoutRepository(failingAtSave: 1)
        let fixture = RunSessionFixture(recorder: StubRunWorkoutRecorder(defersWrite: true), workouts: workouts)
        let snapshot = try await fixture.service.start(.free())
        await fixture.push(Array(trace(meters: 300)[1...]))
        await #expect(throws: CountingWorkoutRepository.Failure.interrupted) { try await fixture.service.finish() }
        let draft = try #require(try await fixture.drafts.load())
        #expect(draft.healthWriteDeferred)
        #expect(draft.healthKitUUID == nil)

        let recorder = StubRunWorkoutRecorder()
        let recap = try await fixture.relaunched(recorder: recorder).saveInterrupted()
        #expect(await recorder.saved.isEmpty)
        #expect(recap.session.id == snapshot.sessionID)
        #expect(recap.session.healthKitUUID == nil)
    }

    /// Un brouillon d'une course dont l'entraînement attend déjà le déverrouillage : rien n'est écrit à nouveau.
    @Test func interruptedRunWithADeferredWriteIsNotWrittenAgain() async throws {
        var draft = RunSessionFixture.interruptedDraft(meters: 1_000)
        draft.healthWriteDeferred = true
        let fixture = RunSessionFixture(draft: draft)
        let recap = try await fixture.service.saveInterrupted()
        #expect(await fixture.recorder.saved.isEmpty)
        #expect(recap.session.healthKitUUID == nil)
        #expect(try await fixture.drafts.load() == nil)
    }

    /// L'entraînement d'une course interrompue écrit, puis l'enregistrement dans Pulse échoue : le nouvel essai le réutilise.
    @Test func interruptedRunKeepsItsWorkoutAcrossAFailedSave() async throws {
        let draft = RunSessionFixture.interruptedDraft(meters: 1_000)
        let workouts = CountingWorkoutRepository(failingAtSave: 1)
        let fixture = RunSessionFixture(draft: draft, workouts: workouts)
        await #expect(throws: CountingWorkoutRepository.Failure.interrupted) { try await fixture.service.saveInterrupted() }
        let kept = try #require(try await fixture.drafts.load()?.healthKitUUID)

        let recap = try await fixture.service.saveInterrupted()
        #expect(await fixture.recorder.saved.count == 1)
        #expect(recap.session.healthKitUUID == kept.uuidString)
    }
}
