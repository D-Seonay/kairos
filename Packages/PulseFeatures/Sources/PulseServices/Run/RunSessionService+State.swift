import Foundation
import PulseDomain

/// La course en cours dans ce processus : le brouillon (source de vérité, écrit pour la reprise), le calcul de la distance et les
/// repères des cadences.
struct ActiveRun {
    var draft: RunDraft
    var builder: RunTrackBuilder
    /// Vrai si une séance HealthKit tourne : refus de Santé ou échec du départ la laissent de côté.
    var recordsHealth: Bool
    var gps = RunGPSQuality.searching
    var heartRate: Double?
    var lastDraftWrite: Date
    var lastActivityUpdate: Date
    var lastResumeAt: Date?
    /// Le déplacement à partir duquel le dernier rappel d'oubli a été programmé.
    var reminderReference: Date
    /// Progression vers l'objectif au dernier point en mouvement, pour n'annoncer chaque palier qu'une fois.
    var progress: Double?
    /// Avance à chaque pause et reprise : les effets calculés avant ne s'appliquent plus.
    var generation = 0

    init(draft: RunDraft, builder: RunTrackBuilder? = nil, recordsHealth: Bool, at date: Date) {
        self.draft = draft
        self.builder = builder ?? RunTrackBuilder(startedAt: draft.startedAt)
        self.recordsHealth = recordsHealth
        lastDraftWrite = date
        lastActivityUpdate = date
        lastResumeAt = draft.pauses.last?.end
        reminderReference = draft.startedAt
        let moving = RunClock.movingSeconds(from: draft.startedAt, pauses: draft.pauses, at: date)
        progress = draft.launch.targetProgress(movingSeconds: moving, distanceMeters: distance)
        reminderReference = movementReference
    }

    var sessionID: UUID { draft.sessionID }

    var isPaused: Bool { draft.pauses.last.map { $0.end == nil } ?? false }

    /// `nil` sans localisation : la course n'a que son temps.
    var distance: Double? { draft.locationDenied ? nil : builder.distanceMeters }

    /// Le dernier déplacement, la dernière reprise ou le départ : le builder ne compte pas le point qui ouvre un segment.
    var movementReference: Date {
        max(builder.lastMovementAt ?? draft.startedAt, lastResumeAt ?? draft.startedAt, draft.startedAt)
    }

    /// Le brouillon est écrit maintenant : il est daté et le repère de la cadence revient à `date`.
    mutating func markDraftWritten(at date: Date) {
        draft.updatedAt = date
        lastDraftWrite = date
    }

    /// Les annonces dues au point d'horodatage `date` : km passé, mi-objectif, objectif atteint.
    mutating func announcementEvents(kilometer: Int?, at date: Date) -> [RunAnnouncementEvent] {
        let moving = RunClock.movingSeconds(from: draft.startedAt, pauses: draft.pauses, at: date)
        let progress = draft.launch.targetProgress(movingSeconds: moving, distanceMeters: distance)
        let splits = kilometer == nil ? [] : builder.splits(pauses: draft.pauses, end: date)
        // Le temps annoncé est celui du passage au km, somme des temps par km, pas celui du point qui l'a franchi.
        let crossing = kilometer.map { passed in splits.prefix(passed).reduce(0) { $0 + $1.seconds } } ?? moving
        let events = RunAnnouncementEvent.events(
            kilometer: kilometer, splits: splits, movingSeconds: crossing, previousProgress: self.progress, progress: progress)
        self.progress = progress
        return events
    }
}

extension RunSessionService {
    func snapshot(of active: ActiveRun, at date: Date) -> RunSnapshot {
        let pauses = active.draft.pauses
        let moving = RunClock.movingSeconds(from: active.draft.startedAt, pauses: pauses, at: date)
        let distance = active.distance
        return RunSnapshot(
            sessionID: active.sessionID, launch: active.draft.launch, startedAt: active.draft.startedAt, pauses: pauses,
            isPaused: active.isPaused, movingSeconds: moving, distanceMeters: distance,
            currentKilometerPace: distance == nil ? nil : active.builder.currentKilometerPace(pauses: pauses, at: date),
            averagePace: distance == nil ? nil : active.builder.averagePace(pauses: pauses, at: date),
            heartRate: active.heartRate,
            targetProgress: active.draft.launch.targetProgress(movingSeconds: moving, distanceMeters: distance), gps: active.gps,
            locationDenied: active.draft.locationDenied)
    }

    /// En mouvement, le chronomètre système part de `date − temps en mouvement` ; en pause, le temps est figé.
    func activityState(of active: ActiveRun, at date: Date) -> RunActivityState {
        let pauses = active.draft.pauses
        let moving = RunClock.movingSeconds(from: active.draft.startedAt, pauses: pauses, at: date)
        return RunActivityState(
            sessionID: active.sessionID, title: active.draft.launch.title,
            timerStart: active.isPaused ? nil : date.addingTimeInterval(-moving), frozenElapsedSeconds: Int(moving),
            distanceMeters: active.distance,
            averagePaceSecondsPerKm: active.distance == nil ? nil : active.builder.averagePace(pauses: pauses, at: date),
            isPaused: active.isPaused)
    }
}

/// Ce qu'un changement de la course doit faire hors de l'acteur.
struct RunEffects {
    /// La génération de pause de la course quand les effets ont été calculés.
    var generation: Int
    var texts: [String] = []
    var savesDraft = false
    var updatesActivity = false
    var reminder: ReminderChange?
}

enum ReminderChange {
    case schedule(Date)
    case cancel
}
