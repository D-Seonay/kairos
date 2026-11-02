import Foundation
import PulseDomain
@testable import PulsePersistence
import Testing

@Test func recordsFilterByExercise() async throws {
    let repo = SwiftDataPersonalRecordRepository(modelContainer: try TestContainer.make())
    let bench = ExerciseReference.content(id: "bench-press-barbell")
    let custom = ExerciseReference.user(id: UUID())
    let older = Sample.record(exercise: bench, date: Fixed.t0)
    let newer = Sample.record(exercise: bench, date: Fixed.t0.addingTimeInterval(86_400))
    let other = Sample.record(exercise: custom, date: Fixed.t1)
    for record in [older, other, newer] { try await repo.save(record) }
    #expect(try await repo.records(for: nil).count == 3)
    #expect(try await repo.records(for: bench).map(\.id) == [newer.id, older.id])
    #expect(try await repo.records(for: custom).map(\.id) == [other.id])
    try await repo.delete(id: newer.id)
    #expect(try await repo.records(for: bench).map(\.id) == [older.id])
}

@Test func replaceAllKeepsMatchingRecordsAndRetiresTheRest() async throws {
    let repo = SwiftDataPersonalRecordRepository(modelContainer: try TestContainer.make())
    let bench = ExerciseReference.content(id: "bench-press-barbell")
    let (setA, setB, setC) = (UUID(), UUID(), UUID())
    func record(set: UUID, kind: RecordKind, value: Double, weight: Double? = nil) -> PersonalRecord {
        PersonalRecord(exercise: bench, exerciseName: "Développé couché", kind: kind, value: value, weightKg: weight, date: Fixed.t0,
                       sessionID: UUID(), setID: set, createdAt: Fixed.t1, updatedAt: Fixed.t2)
    }
    let aMaxWeight = record(set: setA, kind: .maxWeight, value: 70)
    for original in [aMaxWeight, record(set: setA, kind: .estimatedOneRepMax, value: 90), record(set: setB, kind: .maxWeight, value: 60)] {
        try await repo.save(original)
    }
    let updated = record(set: setA, kind: .maxWeight, value: 75)
    try await repo.replaceAll(with: [updated, record(set: setC, kind: .repsAtWeight, value: 10, weight: 60)])
    let after = try await repo.records(for: nil)
    #expect(after.count == 2)
    #expect(after.first { $0.setID == setA && $0.kind == .maxWeight }?.id == aMaxWeight.id)
    #expect(after.first { $0.setID == setA && $0.kind == .maxWeight }?.value == 75)
    #expect(after.contains { $0.setID == setC && $0.kind == .repsAtWeight })
}

@Test func replaceAllWithNothingRetiresEveryRecord() async throws {
    let repo = SwiftDataPersonalRecordRepository(modelContainer: try TestContainer.make())
    try await repo.save(Sample.record())
    try await repo.replaceAll(with: [])
    #expect(try await repo.records(for: nil).isEmpty)
}

@Test func replaceAllLeavesIdenticalRecordsUntouched() async throws {
    let repo = SwiftDataPersonalRecordRepository(modelContainer: try TestContainer.make())
    let (setA, setB) = (UUID(), UUID())
    func record(set: UUID, value: Double) -> PersonalRecord {
        PersonalRecord(exercise: .content(id: "bench-press-barbell"), exerciseName: "Développé couché", kind: .maxWeight, value: value,
                       date: Fixed.t0, sessionID: UUID(), setID: set, createdAt: Fixed.t1, updatedAt: Fixed.t1)
    }
    let (keep, change) = (record(set: setA, value: 70), record(set: setB, value: 60))
    try await repo.replaceAll(with: [keep, change])
    let first = try await repo.records(for: nil)
    var changed = change
    changed.value = 62.5
    try await repo.replaceAll(with: [keep, changed])
    let second = try await repo.records(for: nil)
    func stored(_ records: [PersonalRecord], _ set: UUID) throws -> PersonalRecord {
        try #require(records.first { $0.setID == set })
    }
    #expect(try stored(second, setA).updatedAt == stored(first, setA).updatedAt)
    #expect(try stored(second, setB).updatedAt > stored(first, setB).updatedAt)
    #expect(try stored(second, setB).value == 62.5)
}
