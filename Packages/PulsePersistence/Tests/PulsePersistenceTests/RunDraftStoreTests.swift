import Foundation
import PulseDomain
@testable import PulsePersistence
import SwiftData
import Testing

/// Un point par seconde depuis `Fixed.t0`.
private func point(_ second: Int) -> RunTrackPoint {
    RunTrackPoint(timestamp: Fixed.t0.addingTimeInterval(Double(second)), latitude: 48.85 + Double(second) * 0.00001,
                  longitude: 2.35, altitude: 35, horizontalAccuracy: 5, verticalAccuracy: 3)
}

/// Le brouillon après `seconds` secondes de course : un point par seconde, une FC toutes les 5 s.
private func draft(id: UUID, seconds: Int) -> RunDraft {
    var draft = Sample.runDraft(sessionID: id, updatedAt: Fixed.t0.addingTimeInterval(Double(seconds)))
    draft.points = (0..<seconds).map(point)
    draft.heartRates = (0..<(seconds / 5)).map { 140 + Double($0 % 30) }
    return draft
}

/// Une course de 2 h sauvegardée toutes les 10 s, comme `RunSessionService` : la reprise, par un autre dépôt (relance après
/// plantage), retrouve le dernier brouillon entier.
@Test func aLongDraftSavedEveryTenSecondsRecoversEntirely() async throws {
    let container = try TestContainer.make()
    let store = SwiftDataRunDraftStore(modelContainer: container)
    let id = UUID()
    for seconds in stride(from: 10, through: 7_200, by: 10) {
        try await store.save(draft(id: id, seconds: seconds))
    }
    let recovered = try await SwiftDataRunDraftStore(modelContainer: container).load()
    #expect(recovered == draft(id: id, seconds: 7_200))
    #expect(recovered?.points.count == 7_200 && recovered?.heartRates.count == 1_440)
}

/// Chaque sauvegarde réécrit un en-tête de taille fixe et ajoute un petit paquet : rien ne grossit avec la durée.
@Test func eachSaveWritesAFixedHeaderAndOneSmallChunk() async throws {
    let container = try TestContainer.make()
    let store = SwiftDataRunDraftStore(modelContainer: container)
    let id = UUID()
    try await store.save(draft(id: id, seconds: 10))
    let firstHeader = try #require(try ModelContext(container).fetch(FetchDescriptor<StoredRunDraft>()).first?.payload?.count)
    for seconds in stride(from: 20, through: 3_600, by: 10) {
        try await store.save(draft(id: id, seconds: seconds))
    }
    let context = ModelContext(container)
    let header = try #require(try context.fetch(FetchDescriptor<StoredRunDraft>()).first)
    #expect(try #require(header.payload?.count) <= firstHeader + 16)
    #expect(header.storedPointCount == 3_600 && header.chunkCount == 360)
    let chunks = try context.fetch(FetchDescriptor<StoredRunDraftChunk>())
    #expect(chunks.count == 360)
    #expect(chunks.allSatisfy { ($0.points?.count ?? 0) < 2_000 })
}

/// Un tracé qui ne prolonge plus ce qui est écrit (points retirés, ou remplacés) est réécrit en entier.
@Test func aTrackThatNoLongerExtendsIsRewritten() async throws {
    let container = try TestContainer.make()
    let store = SwiftDataRunDraftStore(modelContainer: container)
    let id = UUID()
    try await store.save(draft(id: id, seconds: 60))
    let shorter = draft(id: id, seconds: 30)
    try await store.save(shorter)
    #expect(try await store.load() == shorter)
    var shifted = draft(id: id, seconds: 40)
    shifted.points[29] = point(1_000)
    try await store.save(shifted)
    #expect(try await store.load() == shifted)
    #expect(try ModelContext(container).fetchCount(FetchDescriptor<StoredRunDraftChunk>()) == 1)
}

/// Une autre course remplace le brouillon et ses paquets ; `clear` efface tout.
@Test func anotherRunReplacesTheDraftAndItsChunks() async throws {
    let container = try TestContainer.make()
    let store = SwiftDataRunDraftStore(modelContainer: container)
    try await store.save(draft(id: UUID(), seconds: 20))
    try await store.save(draft(id: UUID(), seconds: 30))
    let other = draft(id: UUID(), seconds: 15)
    try await store.save(other)
    #expect(try await store.load() == other)
    let context = ModelContext(container)
    #expect(try context.fetch(FetchDescriptor<StoredRunDraftChunk>()).allSatisfy { $0.draftID == other.sessionID })
    try await store.clear()
    #expect(try await store.load() == nil)
    #expect(try context.fetchCount(FetchDescriptor<StoredRunDraftChunk>()) == 0)
}

/// Un brouillon d'avant la V9, tout dans `payload`, se relit tel quel ; la sauvegarde suivante le passe en paquets.
@Test func aDraftInTheOldFormatStaysReadable() async throws {
    let container = try TestContainer.make()
    let id = UUID()
    let old = draft(id: id, seconds: 120)
    let context = ModelContext(container)
    let row = StoredRunDraft(id: id)
    row.payload = try JSONEncoder().encode(old)
    context.insert(row)
    try context.save()
    let store = SwiftDataRunDraftStore(modelContainer: container)
    #expect(try await store.load() == old)
    let next = draft(id: id, seconds: 130)
    try await store.save(next)
    #expect(try await store.load() == next)
    #expect(try ModelContext(container).fetch(FetchDescriptor<StoredRunDraft>()).first?.isChunked == true)
}

/// Mesure, sans seuil : la sauvegarde à 2 h de course, avant (tout le brouillon réencodé) et après (en-tête et paquet).
@Test func writeTimeAtTwoHoursBeforeAndAfter() async throws {
    let container = try TestContainer.make()
    let store = SwiftDataRunDraftStore(modelContainer: container)
    let id = UUID()
    for seconds in stride(from: 10, through: 7_190, by: 10) {
        try await store.save(draft(id: id, seconds: seconds))
    }
    let last = draft(id: id, seconds: 7_200)
    let clock = ContinuousClock()
    let after = try await clock.measure { try await store.save(last) }
    // L'ancien chemin : tout le brouillon réencodé dans l'en-tête, dans un autre magasin.
    let legacy = ModelContext(try TestContainer.make())
    let row = StoredRunDraft(id: id)
    legacy.insert(row)
    row.payload = try JSONEncoder().encode(draft(id: id, seconds: 7_190))
    try legacy.save()
    let before = try clock.measure {
        row.payload = try JSONEncoder().encode(last)
        row.updatedAt = last.updatedAt
        try legacy.save()
    }
    print("Brouillon à 2 h : avant \(before) (\(row.payload?.count ?? 0) octets réécrits), après \(after)")
    #expect(try await store.load() == last)
}
