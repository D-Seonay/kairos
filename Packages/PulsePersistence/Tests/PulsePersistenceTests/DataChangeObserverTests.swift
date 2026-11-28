import Foundation
import PulseDomain
@testable import PulsePersistence
import SwiftData
import Testing

/// Ce qu'un enregistrement de `context` a touché, lu comme l'observateur le lit.
@MainActor
private func savedEntities(in context: ModelContext, _ write: () throws -> Void) throws -> Set<String>? {
    let names = Captured()
    let token = NotificationCenter.default.addObserver(forName: ModelContext.didSave, object: context, queue: nil) { notification in
        names.value = DataChangeObserver.entityNames(in: notification.userInfo)
    }
    defer { NotificationCenter.default.removeObserver(token) }
    try write()
    try context.save()
    return try #require(names.value)
}

/// Ce que l'observateur du test a lu ; écrit pendant `save()`, sur le même fil.
private final class Captured: @unchecked Sendable {
    var value: Set<String>??
}

/// Les brouillons de la course et de la séance, réécrits en continu, ne font pas tout relire ; un score, si.
@MainActor
@Test func onlyDraftWritesAreIgnored() throws {
    let container = try TestContainer.make()
    let context = ModelContext(container)
    let draftOnly = try savedEntities(in: context) {
        context.insert(StoredRunDraft(id: UUID()))
    }
    #expect(draftOnly == [String(describing: StoredRunDraft.self)])
    #expect(!DataChangeObserver.isRelevant(entityNames: draftOnly))

    let score = try savedEntities(in: context) {
        context.insert(StoredDailyRecovery(Sample.recovery()))
    }
    #expect(DataChangeObserver.isRelevant(entityNames: score))
    #expect(DataChangeObserver.isRelevant(entityNames: [String(describing: StoredRunDraftChunk.self), "StoredWorkoutSession"]))
    #expect(DataChangeObserver.isRelevant(entityNames: nil))
}

/// Un changement de fuseau prévient aussi, comme un changement extérieur : le jour civil a pu changer ; un enregistrement de
/// l'app prévient comme un enregistrement.
@MainActor
@Test func aTimeZoneChangeIsAnExternalChange() throws {
    let center = NotificationCenter()
    let kinds = Kinds()
    let observer = DataChangeObserver(center: center) { kinds.append($0) }
    center.post(name: .NSSystemTimeZoneDidChange, object: nil)
    center.post(name: ModelContext.didSave, object: nil, userInfo: nil)
    #expect(kinds.value == [.external, .save])
    withExtendedLifetime(observer) {}
}

private final class Kinds: @unchecked Sendable {
    private let lock = NSLock()
    private var kinds: [DataChangeObserver.Kind] = []

    var value: [DataChangeObserver.Kind] { lock.withLock { kinds } }

    func append(_ kind: DataChangeObserver.Kind) { lock.withLock { kinds.append(kind) } }
}
