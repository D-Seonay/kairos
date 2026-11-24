import Foundation
import PulseDomain

/// Les règles des photos de séance : quelles séances en reçoivent, et combien de places restent.
public enum SessionPhotoRules {
    /// Les séances Apple Santé ne prennent pas de photo : leur fiche est reconstruite depuis Santé, pas gardée par Pulse.
    public static func acceptsPhotos(_ session: WorkoutSession) -> Bool {
        session.source != .appleHealth
    }

    /// Les places libres d'une séance qui en a déjà `current` ; jamais négatif.
    public static func remainingSlots(current: Int) -> Int {
        max(0, SessionPhoto.maxPerSession - current)
    }
}
