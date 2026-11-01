import Foundation
import PulseDomain
import SwiftData

/// Un seul emplacement : la séance en cours.
@ModelActor
public actor SwiftDataActiveSessionStore: ActiveSessionStore {
    public func load() throws -> ActiveSessionSnapshot? {
        try modelContext.fetch(FetchDescriptor<StoredActiveSessionSnapshot>()).first?.toDomain()
    }

    public func save(_ snapshot: ActiveSessionSnapshot) throws {
        try modelContext.delete(model: StoredActiveSessionSnapshot.self)
        modelContext.insert(StoredActiveSessionSnapshot(snapshot))
        try modelContext.save()
    }

    public func clear() throws {
        try modelContext.delete(model: StoredActiveSessionSnapshot.self)
        try modelContext.save()
    }
}
