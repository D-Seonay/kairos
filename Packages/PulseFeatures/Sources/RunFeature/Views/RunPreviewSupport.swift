#if DEBUG
import Foundation
import PulseDomain
import PulseServices

/// Des coordinateurs de course pour les aperçus, sur les doublures du domaine et des dépôts en mémoire : le départ, la course en
/// cours ou en pause, la localisation refusée et le récap. À garder en `@State` : le modèle ne retient pas son coordinateur.
@MainActor
enum RunPreviewSupport {
    static let start = Date(timeIntervalSinceNow: -1_453)
    static let launch = RunLaunch(title: "Footing facile", runType: .easy, targetMinutes: 30,
                                  adjustmentNote: "au lieu du fractionné")

    static func coordinator(location: StubRunLocationTracker = StubRunLocationTracker()) -> RunCoordinator {
        let tracks = InMemoryRunTrackRepository()
        let preferences = InMemoryRunPreferencesStore()
        let service = RunSessionService(
            recorder: StubRunWorkoutRecorder(), location: location, announcer: StubRunAnnouncer(),
            activity: StubRunActivityController(), reminders: StubRunReminderScheduler(), drafts: InMemoryRunDraftStore(),
            workouts: InMemoryWorkoutRepository(), tracks: tracks, profiles: InMemoryProfileRepository(),
            preferences: preferences, spokenText: RunText.spokenText(for:), now: { Date() }, calendar: .current)
        return RunCoordinator(environment: RunEnvironment(
            service: service, tracks: tracks, preferences: preferences, isStrengthSessionActive: { false }, now: { Date() },
            calendar: .current))
    }

    static func startCoordinator() -> RunCoordinator {
        let coordinator = coordinator()
        coordinator.prepare(launch)
        return coordinator
    }

    static func runningCoordinator(paused: Bool = false, locationDenied: Bool = false) -> RunCoordinator {
        let coordinator = coordinator()
        coordinator.showRunning(snapshot(paused: paused, locationDenied: locationDenied))
        return coordinator
    }

    static func recapCoordinator() -> RunCoordinator {
        let coordinator = coordinator()
        coordinator.model().showRecap(recapData)
        return coordinator
    }

    static func snapshot(paused: Bool = false, locationDenied: Bool = false) -> RunSnapshot {
        let pauses = paused ? [RunPause(start: Date(timeIntervalSinceNow: -60))] : []
        return RunSnapshot(
            sessionID: UUID(), launch: launch, startedAt: start, pauses: pauses, isPaused: paused, movingSeconds: 1_393,
            distanceMeters: locationDenied ? nil : 4_380, currentKilometerPace: locationDenied ? nil : 331,
            averagePace: locationDenied ? nil : 332, heartRate: locationDenied ? nil : 152, targetProgress: 0.81,
            gps: locationDenied ? .searching : .ready, locationDenied: locationDenied)
    }

    static let splits: [RunSplit] = [
        RunSplit(kilometer: 1, seconds: 341, distanceMeters: 1_000),
        RunSplit(kilometer: 2, seconds: 335, distanceMeters: 1_000),
        RunSplit(kilometer: 3, seconds: 332, distanceMeters: 1_000),
        RunSplit(kilometer: 4, seconds: 328, distanceMeters: 1_000),
        RunSplit(kilometer: 5, seconds: 125, distanceMeters: 380)
    ]

    /// Une boucle d'environ 4,4 km autour d'un parc.
    static func loop() -> [RunTrackPoint] {
        let center = (latitude: 48.8462, longitude: 2.3371)
        let radius = 700.0
        return (0...120).map { step in
            let angle = Double(step) / 120 * 2 * .pi
            let wobble = 1 + 0.08 * sin(angle * 5)
            return RunTrackPoint(
                timestamp: start.addingTimeInterval(Double(step) * 12),
                latitude: center.latitude + radius * wobble * sin(angle) / 111_195,
                longitude: center.longitude + radius * wobble * cos(angle) / (111_195 * cos(center.latitude * .pi / 180)),
                horizontalAccuracy: 5)
        }
    }

    static var recapData: RunRecapData {
        let id = UUID()
        let session = WorkoutSession(
            id: id, startedAt: start, endedAt: Date(), kind: .run, source: .pulse, status: .completed, title: launch.title,
            durationMinutes: 1_453.0 / 60, distanceMeters: 4_380, averageHeartRate: 152, createdAt: Date(), updatedAt: Date())
        let track = RunTrack(id: id, points: loop(), splits: splits, elevationGainMeters: 42, createdAt: Date(), updatedAt: Date())
        return RunRecapData(session: session, track: track)
    }
}
#endif
