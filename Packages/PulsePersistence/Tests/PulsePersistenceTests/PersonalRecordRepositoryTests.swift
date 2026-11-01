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
