import Foundation
import PulseDomain
import PulseServices
import Testing

struct InMemoryRunRepositoriesTests {
    private let start = TestClock.date("2026-11-02T08:00")

    private func track(_ id: UUID) -> RunTrack {
        RunTrack(id: id, points: [RunTrackPoint(timestamp: start, latitude: 48.85, longitude: 2.35, horizontalAccuracy: 5)],
                 splits: [RunSplit(kilometer: 1, seconds: 330, distanceMeters: 1_000)], elevationGainMeters: 8,
                 createdAt: start, updatedAt: start)
    }

    @Test func runTrackSaveReplacesAndDeleteHidesIt() async throws {
        let repository = InMemoryRunTrackRepository()
        let id = UUID()
        #expect(try await repository.track(for: id) == nil)
        try await repository.save(track(id))
        var edited = track(id)
        edited.elevationGainMeters = 20
        try await repository.save(edited)
        #expect(try await repository.track(for: id) == edited)
        try await repository.delete(sessionID: id)
        #expect(try await repository.track(for: id) == nil)
        try await repository.delete(sessionID: UUID())
        try await repository.save(edited)
        #expect(try await repository.track(for: id) == edited)
    }

    @Test func draftStoreKeepsTheLastDraft() async throws {
        let store = InMemoryRunDraftStore()
        #expect(try await store.load() == nil)
        let first = RunDraft(sessionID: UUID(), launch: RunLaunch(title: "Footing"), startedAt: start, updatedAt: start)
        let second = RunDraft(sessionID: UUID(), launch: RunLaunch(title: "Sortie longue"), startedAt: start,
                              heartRates: [150], updatedAt: start.addingTimeInterval(10))
        try await store.save(first)
        try await store.save(second)
        #expect(try await store.load() == second)
        try await store.clear()
        #expect(try await store.load() == nil)
    }
}
