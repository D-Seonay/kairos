import Foundation
import PulseDomain
@testable import PulsePersistence
import SwiftData
import Testing

@Test func runTrackRoundTrips() async throws {
    let repo = SwiftDataRunTrackRepository(modelContainer: try TestContainer.make())
    let track = Sample.runTrack()
    #expect(try await repo.track(for: track.id) == nil)
    let before = Date()
    try await repo.save(track)
    var loaded = try #require(try await repo.track(for: track.id))
    #expect(loaded.updatedAt >= before)
    loaded.updatedAt = track.updatedAt
    #expect(loaded == track)

    var edited = track
    edited.elevationGainMeters = 20
    edited.splits.removeLast()
    try await repo.save(edited)
    #expect(try await repo.track(for: track.id)?.splits == edited.splits)
    #expect(try await repo.track(for: track.id)?.elevationGainMeters == 20)
    let context = ModelContext(repo.modelContainer)
    #expect(try context.fetchCount(FetchDescriptor<StoredRunTrack>()) == 1)

    try await repo.delete(sessionID: track.id)
    #expect(try await repo.track(for: track.id) == nil)
    let rows = try ModelContext(repo.modelContainer).fetch(FetchDescriptor<StoredRunTrack>())
    #expect(rows.count == 1 && rows.first?.deletedAt != nil)
    try await repo.delete(sessionID: UUID())   // sans effet

    // Réenregistrer un tracé supprimé le fait revenir, sur la même ligne.
    try await repo.save(track)
    #expect(try await repo.track(for: track.id)?.points == track.points)
    #expect(try ModelContext(repo.modelContainer).fetchCount(FetchDescriptor<StoredRunTrack>()) == 1)
}

@Test func draftStoreKeepsOneDraft() async throws {
    let store = SwiftDataRunDraftStore(modelContainer: try TestContainer.make())
    #expect(try await store.load() == nil)
    let first = Sample.runDraft(updatedAt: Fixed.t1)
    var second = Sample.runDraft(updatedAt: Fixed.t2)
    second.locationDenied = true
    try await store.save(first)
    try await store.save(second)
    #expect(try await store.load() == second)
    #expect(try ModelContext(store.modelContainer).fetchCount(FetchDescriptor<StoredRunDraft>()) == 1)
    // Le même brouillon réécrit (toutes les 10 s) reste sur une seule ligne.
    second.points.append(Sample.runPoint(3))
    try await store.save(second)
    #expect(try await store.load() == second)
    #expect(try ModelContext(store.modelContainer).fetchCount(FetchDescriptor<StoredRunDraft>()) == 1)
    try await store.clear()
    #expect(try await store.load() == nil)
}
