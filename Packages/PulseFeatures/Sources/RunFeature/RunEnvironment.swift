import Foundation
import PulseDomain
import PulseServices

/// Tout ce dont la course a besoin du dehors : le service de la course, les tracés, les réglages, l'état de la séance de
/// musculation (une seule séance à la fois), l'horloge et le calendrier.
public struct RunEnvironment {
    public var service: RunSessionService
    public var tracks: any RunTrackRepository
    public var preferences: any RunPreferencesStore
    /// Vrai si une séance de musculation est en cours : la course ne démarre pas par-dessus.
    public var isStrengthSessionActive: @MainActor () -> Bool
    public var now: @Sendable () -> Date
    public var calendar: Calendar

    public init(service: RunSessionService, tracks: any RunTrackRepository, preferences: any RunPreferencesStore,
                isStrengthSessionActive: @escaping @MainActor () -> Bool, now: @escaping @Sendable () -> Date,
                calendar: Calendar) {
        self.service = service
        self.tracks = tracks
        self.preferences = preferences
        self.isStrengthSessionActive = isStrengthSessionActive
        self.now = now
        self.calendar = calendar
    }
}
