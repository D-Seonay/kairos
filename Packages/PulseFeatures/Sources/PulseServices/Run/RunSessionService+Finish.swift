import Foundation
import PulseDomain

extension RunSessionService {
    // MARK: Fin

    /// Termine, écrit dans Santé (si autorisé), sauve séance + tracé, vide le brouillon. Rend la séance enregistrée.
    public func finish() async throws -> RunRecapData {
        try await finish(at: now())
    }

    /// Termine à l'heure du dernier déplacement (oubli).
    public func finish(at end: Date) async throws -> RunRecapData {
        guard let active = run, !isTransitioning else { throw RunSessionError.noRun }
        run = nil
        stopConsuming()
        if !active.draft.locationDenied { await location.stop() }
        var draft = active.draft
        draft.pauses = Self.pauses(draft.pauses, closedAt: end)
        // Une fin avant le dernier point (oubli) rejoue la course jusqu'à elle ; sinon le builder en direct suffit.
        let builder = end < (draft.points.last?.timestamp ?? end)
            ? RunTrackBuilder.replay(startedAt: draft.startedAt, points: draft.points.filter { $0.timestamp <= end }, pauses: draft.pauses)
            : active.builder
        // Un échec de l'écriture dans Santé n'empêche pas d'enregistrer la course dans Pulse.
        let entry = Self.healthEntry(draft, builder: builder, end: end)
        var healthKitID: UUID?
        if active.recordsHealth { healthKitID = try? await recorder.finish(entry) }
        // Sans séance vivante à terminer (arrêtée par le système, en échec ou jamais partie), l'entraînement est écrit sans elle.
        if healthKitID == nil, await recorder.writeAccess() == .authorized { healthKitID = try? await recorder.save(entry) }
        if let healthKitID {
            // Gardé avant d'enregistrer la séance : si l'enregistrement échoue, la reprise réutilise cet entraînement.
            draft.healthKitUUID = healthKitID
            try? await drafts.save(draft)
        }
        await activity.end()
        await reminders.cancelForgotten()
        let recap = try await persist(draft, builder: builder, end: end, healthKitID: healthKitID)
        try? await drafts.clear()
        endSnapshots()
        return recap
    }

    /// Enregistre la course du brouillon, interrompue sans séance HealthKit vivante : elle s'arrête à son dernier déplacement.
    /// L'entraînement est écrit dans Santé, sauf s'il l'a déjà été par une fin interrompue.
    public func saveInterrupted() async throws -> RunRecapData {
        guard !isTransitioning else { throw RunSessionError.noRun }
        let stored: RunDraft
        if let active = run {
            run = nil
            stopConsuming()
            if active.recordsHealth { await recorder.discard() }
            if !active.draft.locationDenied { await location.stop() }
            stored = active.draft
        } else {
            guard let loaded = try await drafts.load(), await !clearIfAlreadySaved(loaded) else { throw RunSessionError.noRun }
            // Une séance HealthKit rattachée au lancement, sans course pour la mener, est terminée avant d'écrire l'entraînement.
            await recorder.discard()
            stored = loaded
        }
        let end = Self.interruptedEnd(of: stored).end
        var draft = stored
        draft.pauses = Self.pauses(stored.pauses, closedAt: end)
        let builder = RunTrackBuilder.replay(
            startedAt: draft.startedAt, points: draft.points.filter { $0.timestamp <= end }, pauses: draft.pauses)
        // Une fin dont l'enregistrement a échoué a déjà écrit l'entraînement : il n'est pas écrit une seconde fois.
        var healthKitID = draft.healthKitUUID
        if healthKitID == nil, await recorder.writeAccess() == .authorized {
            healthKitID = try? await recorder.save(Self.healthEntry(draft, builder: builder, end: end))
        }
        // La Live Activity du processus interrompu peut encore être affichée.
        await activity.endAll()
        await reminders.cancelForgotten()
        let recap = try await persist(draft, builder: builder, end: end, healthKitID: healthKitID)
        try? await drafts.clear()
        endSnapshots()
        return recap
    }

    /// Abandonne la course en cours, ou le brouillon d'une course interrompue : rien n'est enregistré.
    public func discard() async {
        let active = run
        run = nil
        stopConsuming()
        await stopPreview()
        if let active {
            if active.recordsHealth { await recorder.discard() }
            if !active.draft.locationDenied { await location.stop() }
            await activity.end()
        } else {
            await recorder.discard()
            await activity.endAll()
        }
        await reminders.cancelForgotten()
        try? await drafts.clear()
        endSnapshots()
    }

    // MARK: Récap

    /// Écrit le RPE et la note du récap. `rpe: nil` laisse la séance sans RPE noté : la charge prend alors le RPE estimé.
    public func completeRecap(sessionID: UUID, rpe: Double?, note: String?) async throws {
        guard var session = try await workouts.session(id: sessionID) else { throw RunSessionError.noRun }
        let trimmed = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        session.overallRPE = rpe
        session.note = trimmed?.isEmpty == false ? trimmed : nil
        session.updatedAt = now()
        try await workouts.save(session)
    }

    /// Supprime la séance, son tracé et l'entraînement écrit dans Santé. Un échec côté Santé ne bloque pas la suppression.
    public func deleteRun(sessionID: UUID) async throws {
        let session = try await workouts.session(id: sessionID)
        try await tracks.delete(sessionID: sessionID)
        try await workouts.delete(id: sessionID)
        if let healthKitID = session?.healthKitUUID.flatMap(UUID.init(uuidString:)) {
            try? await recorder.deleteWorkout(id: healthKitID)
        }
    }

    // MARK: Internes

    /// Sauve la séance puis le tracé. La première sauvegarde porte déjà la FC moyenne et le RPE estimé, que le dépôt garde en
    /// local (frontière M8) : les sauvegardes suivantes reprennent ces valeurs stockées.
    private func persist(_ draft: RunDraft, builder: RunTrackBuilder, end: Date, healthKitID: UUID?) async throws -> RunRecapData {
        let date = now()
        let moving = RunClock.movingSeconds(from: draft.startedAt, pauses: draft.pauses, at: end)
        let averageHeartRate = draft.heartRates.isEmpty ? nil : draft.heartRates.reduce(0, +) / Double(draft.heartRates.count)
        let birthDate = (try? await profiles.load())?.birthDate
        let maxHeartRate = EstimatedRPE.maxHeartRate(birthDate: birthDate, at: draft.startedAt, calendar: calendar)
        let session = WorkoutSession(
            id: draft.sessionID, startedAt: draft.startedAt, endedAt: end, kind: .run, source: .pulse, status: .completed,
            programID: draft.launch.programID, routineDayID: draft.launch.routineDayID, title: draft.launch.title,
            durationMinutes: moving / 60, distanceMeters: draft.locationDenied ? nil : builder.distanceMeters,
            averageHeartRate: averageHeartRate,
            estimatedRPE: EstimatedRPE.rpe(averageHeartRate: averageHeartRate, maxHeartRate: maxHeartRate),
            healthKitUUID: healthKitID?.uuidString, createdAt: date, updatedAt: date)
        try await workouts.save(session)
        guard !builder.accepted.isEmpty else { return RunRecapData(session: session, track: nil) }
        let track = RunTrack(
            id: draft.sessionID, points: RouteSimplifier.simplify(builder.accepted),
            splits: builder.splits(pauses: draft.pauses, end: end), elevationGainMeters: builder.elevationGainMeters(),
            createdAt: date, updatedAt: date)
        try await tracks.save(track)
        return RunRecapData(session: session, track: track)
    }

    /// Les pauses bornées à `end` : une pause ouverte s'y ferme, une pause commencée après disparaît.
    static func pauses(_ pauses: [RunPause], closedAt end: Date) -> [RunPause] {
        pauses.compactMap { pause in
            guard pause.start < end else { return nil }
            return RunPause(start: pause.start, end: min(pause.end ?? end, end))
        }
    }

    static func healthEntry(_ draft: RunDraft, builder: RunTrackBuilder, end: Date) -> RunWorkoutEntry {
        RunWorkoutEntry(
            sessionID: draft.sessionID, start: draft.startedAt, end: end, pauses: draft.pauses,
            distanceMeters: draft.locationDenied ? nil : builder.distanceMeters, route: builder.accepted)
    }
}
