import Foundation

public protocol ProfileRepository: Sendable {
    /// Le profil non supprimé le plus ancien par `createdAt`, puis par `id.uuidString` croissant, s'il en existe plusieurs
    /// après une restauration.
    func load() async throws -> UserProfile?
    /// Écrit le profil entier, par son `id` (création, brouillon de l'onboarding, données de départ). Pour modifier quelques champs
    /// d'un profil existant, passer par `update(_:)`, sans quoi une autre écriture entre la lecture et l'enregistrement est perdue.
    func save(_ profile: UserProfile) async throws
    /// Suppression logique : le profil n'est plus renvoyé par `load()`.
    func delete(id: UUID) async throws
    /// Lit le profil de `load()`, lui applique `transform` et l'enregistre, d'un seul tenant : aucune autre écriture ne s'intercale
    /// entre la lecture et l'enregistrement, donc `transform` ne doit toucher que ses propres champs. Rien n'est écrit si `transform`
    /// lève une erreur (elle est relancée) ou laisse le profil inchangé. `nil` sans profil, rien n'est alors écrit.
    @discardableResult
    func update(_ transform: @Sendable (inout UserProfile) throws -> Void) async throws -> ProfileUpdate?
}

/// Le profil avant et après `ProfileRepository.update(_:)`. `after` est le profil tel qu'enregistré.
public struct ProfileUpdate: Sendable, Equatable {
    public var before: UserProfile
    public var after: UserProfile

    public init(before: UserProfile, after: UserProfile) {
        self.before = before
        self.after = after
    }

    /// Faux si `transform` n'a rien changé : rien n'a été écrit.
    public var didChange: Bool { before != after }
}
