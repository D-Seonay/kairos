import Foundation
import PulseDomain
import PulseServices
import Testing

struct InMemorySessionPhotoRepositoryTests {
    private let start = TestClock.date("2026-11-02T08:00")

    private func photo(_ sessionID: UUID, order: Int, createdAt: Date? = nil) -> SessionPhoto {
        SessionPhoto(id: UUID(), sessionID: sessionID, order: order, createdAt: createdAt ?? start, updatedAt: start)
    }

    private func image(_ seed: UInt8) -> PhotoImage {
        PhotoImage(image: Data([seed, 0xFF, 0xD9]), thumbnail: Data([seed]))
    }

    @Test func photosComeBackSortedAndKeepTheirImage() async throws {
        let repository = InMemorySessionPhotoRepository()
        let sessionID = UUID()
        let second = photo(sessionID, order: 1)
        let first = photo(sessionID, order: 0)
        try await repository.add(second, image: image(2))
        try await repository.add(first, image: image(1))
        try await repository.add(photo(UUID(), order: 0), image: image(3))
        #expect(try await repository.photos(for: sessionID) == [first, second])
        #expect(try await repository.image(of: second.id) == image(2))
        #expect(try await repository.image(of: UUID()) == nil)
    }

    @Test func deleteRemovesOnePhotoAndDeleteAllTheSession() async throws {
        let repository = InMemorySessionPhotoRepository()
        let sessionID = UUID()
        let other = photo(UUID(), order: 0)
        let removed = photo(sessionID, order: 0)
        try await repository.add(removed, image: image(1))
        try await repository.add(photo(sessionID, order: 1), image: image(2))
        try await repository.add(other, image: image(3))
        try await repository.delete(photoID: removed.id)
        #expect(try await repository.photos(for: sessionID).count == 1)
        #expect(try await repository.image(of: removed.id) == nil)
        try await repository.deleteAll(sessionID: sessionID)
        #expect(try await repository.photos(for: sessionID).isEmpty)
        #expect(try await repository.photos(for: other.sessionID) == [other])
    }
}
