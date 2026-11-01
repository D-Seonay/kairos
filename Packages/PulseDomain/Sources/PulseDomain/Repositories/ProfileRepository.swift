import Foundation

public protocol ProfileRepository: Sendable {
    /// Le profil non supprimé le plus ancien par `createdAt`, puis par `id.uuidString` croissant, s'il en existe plusieurs
    /// après une restauration.
    func load() async throws -> UserProfile?
    func save(_ profile: UserProfile) async throws
    /// Suppression logique : le profil n'est plus renvoyé par `load()`.
    func delete(id: UUID) async throws
}
