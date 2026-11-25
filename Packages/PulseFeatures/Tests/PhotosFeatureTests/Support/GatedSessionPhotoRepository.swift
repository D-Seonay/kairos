import Foundation
import PulseDomain
import PulseServices

/// Des photos de séance en mémoire dont l'ajout attend un feu vert : le test peut abandonner la séance pendant l'écriture.
actor GatedSessionPhotoRepository: SessionPhotoRepository {
    private let inner = InMemorySessionPhotoRepository()
    private var release: CheckedContinuation<Void, Never>?
    /// Vrai dès qu'un ajout attend son feu vert.
    private(set) var isAdding = false

    func photos(for sessionID: UUID) async throws -> [SessionPhoto] {
        try await inner.photos(for: sessionID)
    }

    func image(of photoID: UUID) async throws -> PhotoImage? {
        try await inner.image(of: photoID)
    }

    func add(_ photo: SessionPhoto, image: PhotoImage) async throws {
        isAdding = true
        await withCheckedContinuation { release = $0 }
        try await inner.add(photo, image: image)
    }

    func delete(photoID: UUID) async throws {
        try await inner.delete(photoID: photoID)
    }

    func deleteAll(sessionID: UUID) async throws {
        try await inner.deleteAll(sessionID: sessionID)
    }

    /// Laisse l'ajout en attente écrire sa photo.
    func open() {
        release?.resume()
        release = nil
    }
}

/// Un chargeur suspendu jusqu'à ce que le test l'ouvre.
actor LoaderGate {
    private var isOpen = false
    private var waiter: CheckedContinuation<Void, Never>?
    /// Vrai dès que le chargeur attend.
    private(set) var isWaiting = false

    func wait() async {
        guard !isOpen else { return }
        isWaiting = true
        await withCheckedContinuation { waiter = $0 }
    }

    func open() {
        isOpen = true
        waiter?.resume()
        waiter = nil
    }
}
