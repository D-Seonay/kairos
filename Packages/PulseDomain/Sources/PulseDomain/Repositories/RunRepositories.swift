import Foundation

/// Le tracé des courses terminées, un par séance.
public protocol RunTrackRepository: Sendable {
    func track(for sessionID: UUID) async throws -> RunTrack?
    /// Crée ou remplace le tracé de la séance.
    func save(_ track: RunTrack) async throws
    /// Supprime le tracé ; sans effet s'il n'existe pas.
    func delete(sessionID: UUID) async throws
}

/// Le brouillon de la course en cours, un seul à la fois, gardé hors du magasin synchronisé.
public protocol RunDraftStore: Sendable {
    func load() async throws -> RunDraft?
    func save(_ draft: RunDraft) async throws
    func clear() async throws
}
