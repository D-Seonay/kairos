import Foundation
import PulseDomain

extension RunSessionService {
    /// Au lancement et au retour au premier plan : le brouillon d'une course que ce processus ne mène pas. La séance HealthKit est
    /// rattachée au passage si le système l'a gardée.
    public func recoveryOffer() async -> RunRecoveryOffer? {
        guard run == nil, !isTransitioning, let draft = try? await drafts.load() else { return nil }
        guard await !clearIfAlreadySaved(draft) else { return nil }
        let isStillRecording = await recorder.recoverActiveSession()
        let (end, builder) = Self.interruptedEnd(of: draft)
        return RunRecoveryOffer(
            sessionID: draft.sessionID, distanceMeters: draft.locationDenied ? nil : builder.distanceMeters, lastPointAt: end,
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

    // MARK: Internes

    /// La fin d'une course interrompue, même règle que l'oubli : son dernier déplacement, sa dernière reprise ou son départ, s'il
    /// précède le dernier point, car les points à l'arrêt ne prolongent pas la course. Sans point retenu (localisation refusée,
    /// pas de signal, positions toutes trop imprécises), le GPS ne dit rien du déplacement : la course va jusqu'à sa dernière
    /// activité connue, la dernière écriture du brouillon, tenue à jour au fil du temps. Rend aussi la course rejouée avec tous
    /// ses points.
    static func interruptedEnd(of draft: RunDraft) -> (end: Date, builder: RunTrackBuilder) {
        let builder = RunTrackBuilder.replay(startedAt: draft.startedAt, points: draft.points, pauses: draft.pauses)
        guard let last = draft.points.last?.timestamp, !builder.accepted.isEmpty else {
            return (max(draft.updatedAt, draft.startedAt), builder)
        }
        let lastResume = draft.pauses.compactMap(\.end).max() ?? draft.startedAt
        let movement = max(builder.lastMovementAt ?? draft.startedAt, lastResume, draft.startedAt)
        return (min(movement, max(last, draft.startedAt)), builder)
    }

    /// Un brouillon dont la course est déjà enregistrée (revenu après coup) est vidé : rien n'est proposé ni écrit une seconde fois,
    /// et une séance HealthKit rattachée pour lui est terminée. Appelé sans course en cours.
    func clearIfAlreadySaved(_ draft: RunDraft) async -> Bool {
        guard (try? await workouts.session(id: draft.sessionID)) != nil else { return false }
        try? await drafts.clear()
        await recorder.discard()
        return true
    }
}
