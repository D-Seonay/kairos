import Foundation
import PulseDomain

extension RunSessionService {
    /// Au lancement et au retour au premier plan : le brouillon d'une course que ce processus ne mène pas. La séance HealthKit est
    /// rattachée au passage si le système l'a gardée.
    public func recoveryOffer() async -> RunRecoveryOffer? {
        guard run == nil, !isTransitioning, let draft = try? await drafts.load() else { return nil }
        let isStillRecording = await recorder.recoverActiveSession()
        let distance = draft.locationDenied
            ? nil : RunTrackBuilder.replay(startedAt: draft.startedAt, points: draft.points, pauses: draft.pauses).distanceMeters
        return RunRecoveryOffer(
            sessionID: draft.sessionID, distanceMeters: distance, lastPointAt: draft.points.last?.timestamp ?? draft.updatedAt,
            isStillRecording: isStillRecording)
    }

    /// Reprend la course du brouillon quand sa séance HealthKit tourne encore : la distance est rejouée, la localisation et la
    /// Live Activity repartent. La FC ne revient pas : le flux est perdu avec le processus.
    public func reattach() async -> RunSnapshot? {
        if run != nil { return current() }
        guard !isTransitioning else { return nil }
        isTransitioning = true
        defer { isTransitioning = false }
        guard let draft = try? await drafts.load(), await recorder.recoverActiveSession() else { return nil }
        let date = now()
        let builder = RunTrackBuilder.replay(startedAt: draft.startedAt, points: draft.points, pauses: draft.pauses)
        let active = ActiveRun(draft: draft, builder: builder, recordsHealth: true, at: date)
        var points: AsyncStream<RunTrackPoint>?
        if !draft.locationDenied { points = await location.start() }
        run = active
        consume(points: points, heartRates: nil)
        // La Live Activity a survécu au processus : elle est retrouvée par l'identifiant de la séance.
        await activity.update(activityState(of: active, at: date))
        if !active.isPaused, !draft.locationDenied {
            await reminders.scheduleForgotten(at: active.reminderReference.addingTimeInterval(Self.forgottenAfter))
        }
        publish()
        return current() ?? snapshot(of: active, at: date)
    }
}
