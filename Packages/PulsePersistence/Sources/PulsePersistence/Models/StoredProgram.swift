import Foundation
import PulseDomain
import SwiftData

@Model
public final class StoredProgram {
    public var id: UUID = UUID()
    public var name: String = ""
    public var templateID: String?
    public var sessionsPerWeek: Int = 0
    public var weekLayout: Data?
    public var isArchived: Bool = false
    @Relationship(deleteRule: .cascade, inverse: \StoredRoutineDay.program) public var days: [StoredRoutineDay]? = []
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()
    public var deletedAt: Date?

    public init(_ program: Program) {
        id = program.id
        createdAt = program.createdAt
        apply(program)
    }

    /// Recopie les champs et réconcilie les jours par identifiant : mise à jour, création, suppression logique.
    public func apply(_ program: Program) {
        name = program.name
        templateID = program.templateID
        sessionsPerWeek = program.sessionsPerWeek
        weekLayout = CodableColumn.encode(program.weekLayout)
        isArchived = program.isArchived
        updatedAt = program.updatedAt
        var remaining = Dictionary((days ?? []).map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for day in program.days {
            if let existing = remaining.removeValue(forKey: day.id) {
                existing.deletedAt = nil
                existing.apply(day, updatedAt: updatedAt)
            } else {
                let stored = StoredRoutineDay(day, updatedAt: updatedAt)
                stored.program = self
                days = (days ?? []) + [stored]
            }
        }
        for orphan in remaining.values where orphan.deletedAt == nil {
            orphan.markDeleted()
        }
    }

    public func toDomain() -> Program {
        Program(id: id, name: name, templateID: templateID, sessionsPerWeek: sessionsPerWeek,
                weekLayout: CodableColumn.decode([UUID?].self, from: weekLayout, default: Array(repeating: nil, count: 7)),
                isArchived: isArchived,
                days: (days ?? []).filter { $0.deletedAt == nil }.sorted { $0.order < $1.order }.map { $0.toDomain() },
                createdAt: createdAt, updatedAt: updatedAt)
    }
}
