import Foundation

/// Les photos des séances, synchronisées par iCloud avec les séances.
public protocol SessionPhotoRepository: Sendable {
    /// Les photos vivantes de la séance, triées par `order` puis `createdAt`.
    func photos(for sessionID: UUID) async throws -> [SessionPhoto]
    func image(of photoID: UUID) async throws -> PhotoImage?
    func add(_ photo: SessionPhoto, image: PhotoImage) async throws
    func delete(photoID: UUID) async throws
    func deleteAll(sessionID: UUID) async throws
}

/// Les photos de corps, gardées sur l'iPhone seulement, en fichiers protégés hors des sauvegardes.
public protocol BodyPhotoStore: Sendable {
    /// Les photos dont le fichier existe, sans ordre garanti.
    func photos() async throws -> [BodyPhoto]
    func image(of photoID: UUID) async throws -> PhotoImage?
    /// Crée ou remplace la photo de même identifiant.
    func save(_ photo: BodyPhoto, image: PhotoImage) async throws
    func delete(photoID: UUID) async throws
    func deleteAll() async throws
    /// Écrit une archive zip des images dans `directory` et rend son URL.
    func exportArchive(to directory: URL) async throws -> URL
}

/// Le code de l'iPhone, qui verrouille les photos de corps.
public protocol DeviceOwnerAuthenticating: Sendable {
    /// Vrai si l'iPhone a un code : sans code, ni verrou ni chiffrement.
    func isAvailable() async -> Bool
    func authenticate(reason: String) async -> Bool
}
