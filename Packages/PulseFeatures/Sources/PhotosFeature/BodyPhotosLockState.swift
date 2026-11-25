import Foundation
import PulseServices

/// Le verrou des photos de corps. `unavailable` : l'iPhone n'a pas de code, il n'y a ni verrou ni chiffrement.
public enum BodyPhotosLockState: Equatable, Sendable {
    case locked
    case unlocked
    case unavailable
}

/// Une photo prête à enregistrer : l'image déjà redressée, réduite et nettoyée, et la date proposée.
public struct BodyPhotoDraft: Equatable, Sendable {
    public var processed: ProcessedPhoto
    /// La date de prise de vue des métadonnées, sinon maintenant ; jamais dans le futur.
    public var takenAt: Date
}
