import Foundation
import PulseDomain
import PulseServices
import Testing

struct SessionPhotoServiceTests {
    private let sessionID = UUID()
    private let repository = InMemorySessionPhotoRepository()

    private func makeService() -> SessionPhotoService {
        SessionPhotoService(repository: repository, timeZone: .gmt, now: { .t0 })
    }

    @Test func addedPhotosKeepTheirOrder() async throws {
        let service = makeService()
        var added: [SessionPhoto] = []
        for _ in 0..<3 { added.append(try await service.add(TestImages.jpeg(), to: sessionID)) }
        #expect(added.map(\.order) == [0, 1, 2])
        #expect(added.allSatisfy { $0.sessionID == sessionID && $0.createdAt == .t0 && $0.updatedAt == .t0 })
        #expect(try await service.photos(for: sessionID).map(\.id) == added.map(\.id))
    }

    @Test func addedPhotoIsStoredProcessedWithItsThumbnail() async throws {
        let service = makeService()
        let photo = try await service.add(TestImages.jpeg(width: 3000, height: 1000), to: sessionID)
        let image = try #require(try await service.image(of: photo.id))
        let thumbnail = try #require(try await service.thumbnail(of: photo.id))
        #expect(!image.isEmpty && !thumbnail.isEmpty && thumbnail.count < image.count)
        #expect(try await service.image(of: UUID()) == nil)
        #expect(try await service.thumbnail(of: UUID()) == nil)
    }

    @Test func serviceRefusesASeventhPhoto() async throws {
        let service = makeService()
        for _ in 0..<SessionPhoto.maxPerSession { _ = try await service.add(TestImages.jpeg(), to: sessionID) }
        await #expect(throws: SessionPhotoError.full) { try await service.add(TestImages.jpeg(), to: sessionID) }
        #expect(try await repository.photos(for: sessionID).count == 6)
    }

    @Test func theLimitIsPerSession() async throws {
        let service = makeService()
        for _ in 0..<SessionPhoto.maxPerSession { _ = try await service.add(TestImages.jpeg(), to: sessionID) }
        let other = try await service.add(TestImages.jpeg(), to: UUID())
        #expect(other.order == 0)
    }

    @Test func unreadableDataThrowsUnreadable() async throws {
        let service = makeService()
        await #expect(throws: SessionPhotoError.unreadable) { try await service.add(Data("pas une image".utf8), to: sessionID) }
        #expect(try await repository.photos(for: sessionID).isEmpty)
    }

    @Test func deletedPhotoFreesASlot() async throws {
        let service = makeService()
        var added: [SessionPhoto] = []
        for _ in 0..<SessionPhoto.maxPerSession { added.append(try await service.add(TestImages.jpeg(), to: sessionID)) }
        try await service.delete(photoID: added[2].id)
        let replacement = try await service.add(TestImages.jpeg(), to: sessionID)
        // La nouvelle photo passe après la plus grande, pas dans le trou laissé.
        #expect(replacement.order == 6)
        #expect(try await service.photos(for: sessionID).count == 6)
    }

    @Test func concurrentAddsKeepTheLimitAndDistinctOrders() async throws {
        let service = makeService()
        let sessionID = sessionID
        let outcomes = await withTaskGroup(of: Result<SessionPhoto, SessionPhotoError>.self) { group in
            for _ in 0..<7 {
                group.addTask {
                    do { return .success(try await service.add(TestImages.jpeg(), to: sessionID)) } catch {
                        return .failure(error as? SessionPhotoError ?? .unreadable)
                    }
                }
            }
            return await group.reduce(into: []) { $0.append($1) }
        }
        let added = outcomes.compactMap { try? $0.get() }
        #expect(added.count == 6)
        #expect(outcomes.filter { if case .failure(.full) = $0 { true } else { false } }.count == 1)
        #expect(Set(added.map(\.order)) == Set(0..<6))
        #expect(try await repository.photos(for: sessionID).count == 6)
    }
}
