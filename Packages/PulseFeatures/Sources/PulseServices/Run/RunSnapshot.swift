import Foundation
import PulseDomain

/// L'état du signal GPS : sans point, avec des points trop imprécis, ou « Prêt » (précision ≤ 20 m).
public enum RunGPSQuality: Sendable, Equatable {
    case searching
    case weak
    case ready

    init(accuracy: Double) {
        self = accuracy >= 0 && accuracy <= RunTrackBuilder.readyAccuracy ? .ready : .weak
    }
}

/// Ce que l'écran de course affiche. Le temps en mouvement est celui de la publication : l'écran le recalcule chaque seconde
/// depuis `startedAt` et `pauses`.
public struct RunSnapshot: Sendable, Equatable {
    public var sessionID: UUID
    public var launch: RunLaunch
    public var startedAt: Date
    public var pauses: [RunPause]
    public var isPaused: Bool
    public var movingSeconds: Double
    /// `nil` si la localisation est refusée.
    public var distanceMeters: Double?
    public var currentKilometerPace: Int?
    public var averagePace: Int?
    /// La dernière FC livrée par la séance HealthKit ; elle reste locale (frontière M8).
    public var heartRate: Double?
    public var targetProgress: Double?
    public var gps: RunGPSQuality
    public var locationDenied: Bool

    public init(sessionID: UUID, launch: RunLaunch, startedAt: Date, pauses: [RunPause], isPaused: Bool, movingSeconds: Double,
                distanceMeters: Double?, currentKilometerPace: Int?, averagePace: Int?, heartRate: Double?,
                targetProgress: Double?, gps: RunGPSQuality, locationDenied: Bool) {
        self.sessionID = sessionID
        self.launch = launch
        self.startedAt = startedAt
        self.pauses = pauses
        self.isPaused = isPaused
        self.movingSeconds = movingSeconds
        self.distanceMeters = distanceMeters
        self.currentKilometerPace = currentKilometerPace
        self.averagePace = averagePace
        self.heartRate = heartRate
        self.targetProgress = targetProgress
        self.gps = gps
        self.locationDenied = locationDenied
    }
}

/// Une course restée en brouillon au lancement : vivante côté HealthKit (à rattacher) ou interrompue (à enregistrer).
public struct RunRecoveryOffer: Sendable, Equatable {
    public var sessionID: UUID
    /// Distance rejouée depuis le brouillon ; `nil` si la localisation était refusée.
    public var distanceMeters: Double?
    /// L'heure où la course s'arrêtera si elle est enregistrée : son dernier déplacement, pas un point à l'arrêt.
    public var lastPointAt: Date
    public var isStillRecording: Bool

    public init(sessionID: UUID, distanceMeters: Double?, lastPointAt: Date, isStillRecording: Bool) {
        self.sessionID = sessionID
        self.distanceMeters = distanceMeters
        self.lastPointAt = lastPointAt
        self.isStillRecording = isStillRecording
    }
}

/// Une course enregistrée, pour le récap : la séance et son tracé (`nil` sans point GPS retenu).
public struct RunRecapData: Sendable, Equatable {
    public var session: WorkoutSession
    public var track: RunTrack?

    public init(session: WorkoutSession, track: RunTrack?) {
        self.session = session
        self.track = track
    }
}

public enum RunSessionError: Error, Equatable {
    /// Une course est déjà en cours, ou un brouillon attend d'être repris.
    case alreadyRunning
    /// Pas de course en cours, ou séance introuvable.
    case noRun
}
