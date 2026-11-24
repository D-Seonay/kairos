import Foundation
import PulseDomain
@testable import PulsePersistence
import SwiftData
import Testing

@Test func sessionPhotosRoundTripInOrder() async throws {
    let repo = SwiftDataSessionPhotoRepository(modelContainer: try TestContainer.make())
    let sessionID = UUID()
    let photos = [2, 0, 1].map { Sample.sessionPhoto(sessionID: sessionID, order: $0) }
    for (index, photo) in photos.enumerated() {
        try await repo.add(photo, image: Sample.photoImage(seed: UInt8(photo.order + index)))
    }
    try await repo.add(Sample.sessionPhoto(sessionID: UUID(), order: 0), image: Sample.photoImage(seed: 9))
    let loaded = try await repo.photos(for: sessionID)
    #expect(loaded.map(\.order) == [0, 1, 2])
    #expect(loaded.map(\.id) == [photos[1].id, photos[2].id, photos[0].id])
    #expect(loaded.allSatisfy { $0.sessionID == sessionID })
    for photo in photos.enumerated() {
        let image = try #require(try await repo.image(of: photo.element.id))
        #expect(image == Sample.photoImage(seed: UInt8(photo.element.order + photo.offset)))
    }
    #expect(try await repo.image(of: UUID()) == nil)
}

@Test func photosWithTheSameOrderAreSortedByCreationDate() async throws {
    let repo = SwiftDataSessionPhotoRepository(modelContainer: try TestContainer.make())
    let sessionID = UUID()
    let late = Sample.sessionPhoto(sessionID: sessionID, order: 0, createdAt: Fixed.t2)
    let early = Sample.sessionPhoto(sessionID: sessionID, order: 0, createdAt: Fixed.t1)
    try await repo.add(late, image: Sample.photoImage(seed: 1))
    try await repo.add(early, image: Sample.photoImage(seed: 2))
    #expect(try await repo.photos(for: sessionID).map(\.id) == [early.id, late.id])
}

@Test func deletedPhotoKeepsNoImage() async throws {
    let repo = SwiftDataSessionPhotoRepository(modelContainer: try TestContainer.make())
    let sessionID = UUID()
    let kept = Sample.sessionPhoto(sessionID: sessionID, order: 0)
    let removed = Sample.sessionPhoto(sessionID: sessionID, order: 1)
    try await repo.add(kept, image: Sample.photoImage(seed: 1))
    try await repo.add(removed, image: Sample.photoImage(seed: 2))
    try await repo.delete(photoID: removed.id)
    #expect(try await repo.photos(for: sessionID).map(\.id) == [kept.id])
    #expect(try await repo.image(of: removed.id) == nil)
    let rows = try ModelContext(repo.modelContainer).fetch(FetchDescriptor<StoredSessionPhoto>())
    let tombstone = try #require(rows.first { $0.id == removed.id })
    #expect(rows.count == 2 && tombstone.deletedAt != nil)
    #expect(tombstone.imageData == nil && tombstone.thumbnailData == nil)
    #expect(try #require(rows.first { $0.id == kept.id }).imageData != nil)
    try await repo.delete(photoID: UUID())   // sans effet
}

@Test func deleteAllClearsOnlyThatSession() async throws {
    let repo = SwiftDataSessionPhotoRepository(modelContainer: try TestContainer.make())
    let sessionID = UUID()
    let other = UUID()
    for order in 0..<3 {
        try await repo.add(Sample.sessionPhoto(sessionID: sessionID, order: order), image: Sample.photoImage(seed: 1))
    }
    try await repo.add(Sample.sessionPhoto(sessionID: other, order: 0), image: Sample.photoImage(seed: 2))
    try await repo.deleteAll(sessionID: sessionID)
    #expect(try await repo.photos(for: sessionID).isEmpty)
    #expect(try await repo.photos(for: other).count == 1)
    let rows = try ModelContext(repo.modelContainer).fetch(FetchDescriptor<StoredSessionPhoto>())
    #expect(rows.filter { $0.sessionID == sessionID }.allSatisfy { $0.imageData == nil && $0.thumbnailData == nil && $0.deletedAt != nil })
    try await repo.deleteAll(sessionID: UUID())   // sans effet
}
