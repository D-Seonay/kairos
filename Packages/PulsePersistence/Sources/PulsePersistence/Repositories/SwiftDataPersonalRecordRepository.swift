import Foundation
import PulseDomain
import SwiftData

@ModelActor
public actor SwiftDataPersonalRecordRepository: PersonalRecordRepository {
    public func records(for exercise: ExerciseReference?) throws -> [PersonalRecord] {
        let descriptor = FetchDescriptor<StoredPersonalRecord>(predicate: #Predicate { $0.deletedAt == nil },
                                                               sortBy: [SortDescriptor(\.date, order: .reverse)])
        let all = try modelContext.fetch(descriptor).map { $0.toDomain() }
        guard let exercise else { return all }
        return all.filter { $0.exercise == exercise }
    }

    public func save(_ record: PersonalRecord) throws {
        var stamped = record
        stamped.updatedAt = Date()
        let id = record.id
        if let existing = try modelContext.first(StoredPersonalRecord.self, where: #Predicate { $0.id == id && $0.deletedAt == nil }) {
            existing.apply(stamped)
        } else {
            modelContext.insert(StoredPersonalRecord(stamped))
        }
        try modelContext.save()
    }

    public func delete(id: UUID) throws {
        let predicate: Predicate<StoredPersonalRecord> = #Predicate { $0.id == id && $0.deletedAt == nil }
        guard let stored = try modelContext.first(StoredPersonalRecord.self, where: predicate) else { return }
        stored.deletedAt = Date()
        try modelContext.save()
    }
}
