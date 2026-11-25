import Foundation
import PulseDomain

/// Les flux de la course en cours (points, FC, tops de maintien) et les effets qu'ils déclenchent hors de l'acteur.
extension RunSessionService {
    // MARK: Flux

    func consume(points: AsyncStream<RunTrackPoint>?, heartRates: AsyncStream<Double>?) {
        if let points {
            pointTask = Task { [weak self] in
                for await point in points { await self?.handle(point) }
            }
        }
        if let heartRates {
            heartRateTask = Task { [weak self] in
                for await bpm in heartRates { await self?.handle(heartRate: bpm) }
            }
        }
        // Sans point ni FC (localisation refusée, pas de signal), le brouillon reste daté au fil du temps : une course
        // interrompue garde ainsi sa durée.
        let ticks = keepAliveTicks(Self.draftInterval)
        keepAliveTask = Task { [weak self] in
            for await _ in ticks { await self?.handleTick() }
        }
    }

    func stopConsuming() {
        pointTask?.cancel()
        pointTask = nil
        heartRateTask?.cancel()
        heartRateTask = nil
        keepAliveTask?.cancel()
        keepAliveTask = nil
    }

    func handle(_ point: RunTrackPoint) async {
        defer {
            handledPointCount += 1
            resumeWaiters()
        }
        // La course sort de `run` le temps des calculs : le tableau des points n'est pas recopié à chaque point.
        guard var active = run else { return }
        run = nil
        let date = now()
        active.draft.points.append(point)
        active.gps = RunGPSQuality(accuracy: point.horizontalAccuracy)
        let wasWatching = active.watchesForgetting
        let kilometer = active.builder.add(point, isPaused: active.isPaused)
        var effects = RunEffects(generation: active.generation)
        if !active.isPaused {
            let events = active.announcementEvents(kilometer: kilometer, at: point.timestamp)
            if preferences.announcesKilometres { effects.texts = events.map(spokenText) }
            let reference = active.movementReference
            // Le premier point retenu ouvre la surveillance de l'oubli ; ensuite, chaque déplacement assez neuf la repousse.
            if active.watchesForgetting,
               !wasWatching || reference.timeIntervalSince(active.reminderReference) > Self.reminderStep {
                active.reminderReference = reference
                effects.reminder = .schedule(reference.addingTimeInterval(Self.forgottenAfter))
            }
        }
        if date.timeIntervalSince(active.lastDraftWrite) >= Self.draftInterval {
            active.markDraftWritten(at: date)
            effects.savesDraft = true
        }
        if kilometer != nil || date.timeIntervalSince(active.lastActivityUpdate) >= Self.activityInterval {
            active.lastActivityUpdate = date
            effects.updatesActivity = true
        }
        run = active
        await apply(effects, for: active.sessionID)
        publish()
    }

    func handle(heartRate bpm: Double) async {
        defer {
            handledHeartRateCount += 1
            resumeWaiters()
        }
        guard var active = run else { return }
        run = nil
        active.heartRate = bpm
        active.draft.heartRates.append(bpm)
        let date = now()
        let savesDraft = date.timeIntervalSince(active.lastDraftWrite) >= Self.draftInterval
        if savesDraft { active.markDraftWritten(at: date) }
        run = active
        await apply(RunEffects(generation: active.generation, savesDraft: savesDraft), for: active.sessionID)
        publish()
    }

    /// Hors pause, le brouillon est réécrit si 10 s ont passé depuis la dernière écriture ; en pause, il est figé depuis la pause.
    func handleTick() async {
        defer {
            handledTickCount += 1
            resumeWaiters()
        }
        guard var active = run, !active.isPaused else { return }
        let date = now()
        guard date.timeIntervalSince(active.lastDraftWrite) >= Self.draftInterval else { return }
        active.markDraftWritten(at: date)
        run = active
        await apply(RunEffects(generation: active.generation, savesDraft: true), for: active.sessionID)
    }

    /// Les effets d'un changement, joués seulement si la course est toujours celle en cours : une fin pendant l'attente ne doit
    /// pas voir un brouillon réécrit après coup. Le brouillon passe en premier, pour la reprise après un crash ; c'est le plus
    /// récent qui est écrit, pas celui d'avant une attente pendant laquelle d'autres points sont arrivés.
    ///
    /// La Live Activity et le rappel dépendent de la pause : une pause ou une reprise terminée pendant l'attente a joué ses propres
    /// effets, et ceux calculés avant elle ne s'appliquent plus. La Live Activity est construite au moment de l'envoi.
    func apply(_ effects: RunEffects, for sessionID: UUID) async {
        if effects.savesDraft, let draft = run?.draft, draft.sessionID == sessionID { try? await drafts.save(draft) }
        if effects.updatesActivity, let active = unchanged(sessionID, effects.generation) {
            await activity.update(activityState(of: active, at: now()))
        }
        switch effects.reminder {
        case .schedule(let date)? where unchanged(sessionID, effects.generation) != nil:
            await reminders.scheduleForgotten(at: date)
        case .cancel? where unchanged(sessionID, effects.generation) != nil:
            await reminders.cancelForgotten()
        default: break
        }
        for text in effects.texts where isCurrent(sessionID) {
            await announcer.announce(text)
        }
    }

    func isCurrent(_ sessionID: UUID) -> Bool {
        run?.sessionID == sessionID
    }

    /// La course en cours si c'est toujours la même, sans pause ni reprise depuis `generation`.
    func unchanged(_ sessionID: UUID, _ generation: Int) -> ActiveRun? {
        guard let active = run, active.sessionID == sessionID, active.generation == generation else { return nil }
        return active
    }
}
