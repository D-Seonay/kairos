import Foundation
import PulseDomain
import SwiftData

@ModelActor
public actor SwiftDataSupplementRepository: SupplementRepository {
    public func supplements(includeArchived: Bool) throws -> [Supplement] {
        let predicate: Predicate<StoredSupplement> = includeArchived
            ? #Predicate { $0.deletedAt == nil }
            : #Predicate { $0.deletedAt == nil && $0.isArchived == false }
        let descriptor = FetchDescriptor<StoredSupplement>(predicate: predicate,
                                                           sortBy: [SortDescriptor(\.order), SortDescriptor(\.createdAt)])
        return try modelContext.fetch(descriptor).map { $0.toDomain() }
    }

    public func save(_ supplement: Supplement) throws {
        var stamped = supplement
        stamped.updatedAt = Date()
        let id = supplement.id
        if let existing = try modelContext.first(StoredSupplement.self, where: #Predicate { $0.id == id && $0.deletedAt == nil }) {
            existing.apply(stamped)
        } else {
            modelContext.insert(StoredSupplement(stamped))
        }
        try modelContext.save()
    }

    public func delete(id: UUID) throws {
        guard let stored = try modelContext.first(StoredSupplement.self, where: #Predicate { $0.id == id && $0.deletedAt == nil }) else {
            return
        }
        stored.deletedAt = Date()
        try modelContext.save()
    }

    public func intakes(from: Date, to: Date) throws -> [SupplementIntake] {
        let descriptor = FetchDescriptor<StoredSupplementIntake>(
            predicate: #Predicate { $0.deletedAt == nil && $0.takenAt >= from && $0.takenAt < to },
            sortBy: [SortDescriptor(\.takenAt), SortDescriptor(\.createdAt)])
        return try modelContext.fetch(descriptor).map { $0.toDomain() }
    }

    public func save(_ intake: SupplementIntake) throws {
        var stamped = intake
        stamped.updatedAt = Date()
        let id = intake.id
        if let existing = try modelContext.first(StoredSupplementIntake.self, where: #Predicate { $0.id == id && $0.deletedAt == nil }) {
            existing.apply(stamped)
        } else {
            modelContext.insert(StoredSupplementIntake(stamped))
        }
        try modelContext.save()
    }

    public func delete(intakeID: UUID) throws {
        let predicate: Predicate<StoredSupplementIntake> = #Predicate { $0.id == intakeID && $0.deletedAt == nil }
        guard let stored = try modelContext.first(StoredSupplementIntake.self, where: predicate) else { return }
        stored.deletedAt = Date()
        try modelContext.save()
    }
}
