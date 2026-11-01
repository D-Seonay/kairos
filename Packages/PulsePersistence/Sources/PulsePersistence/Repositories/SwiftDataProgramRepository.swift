import Foundation
import PulseDomain
import SwiftData

@ModelActor
public actor SwiftDataProgramRepository: ProgramRepository {
    public func programs(includeArchived: Bool) throws -> [Program] {
        let predicate: Predicate<StoredProgram> = includeArchived
            ? #Predicate { $0.deletedAt == nil }
            : #Predicate { $0.deletedAt == nil && $0.isArchived == false }
        let descriptor = FetchDescriptor<StoredProgram>(predicate: predicate,
                                                        sortBy: [SortDescriptor(\.createdAt), SortDescriptor(\.name)])
        return try modelContext.fetch(descriptor).map { $0.toDomain() }
    }

    public func program(id: UUID) throws -> Program? {
        try modelContext.first(StoredProgram.self, where: #Predicate { $0.id == id && $0.deletedAt == nil })?.toDomain()
    }

    public func save(_ program: Program) throws {
        var stamped = program
        stamped.updatedAt = Date()
        let id = program.id
        if let existing = try modelContext.first(StoredProgram.self, where: #Predicate { $0.id == id && $0.deletedAt == nil }) {
            existing.apply(stamped)
        } else {
            modelContext.insert(StoredProgram(stamped))
        }
        try modelContext.save()
    }

    public func delete(id: UUID) throws {
        guard let stored = try modelContext.first(StoredProgram.self, where: #Predicate { $0.id == id && $0.deletedAt == nil }) else {
            return
        }
        let now = Date()
        stored.deletedAt = now
        stored.updatedAt = now
        for day in stored.days ?? [] where day.deletedAt == nil {
            day.markDeleted()
        }
        try modelContext.save()
    }
}
