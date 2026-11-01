import Foundation
import PulseDomain
@testable import PulsePersistence
import Testing

@Test func userExerciseCRUDAndArchivedFilter() async throws {
    let repo = SwiftDataUserExerciseRepository(modelContainer: try TestContainer.make())
    var exercise = Sample.userExercise(name: "Rowing")
    let archived = Sample.userExercise(name: "Ancien", archived: true)
    try await repo.save(exercise)
    try await repo.save(archived)
    #expect(try await repo.all(includeArchived: false).map(\.name) == ["Rowing"])
    #expect(try await repo.all(includeArchived: true).map(\.name) == ["Ancien", "Rowing"])
    exercise.name = "Rowing machine"
    try await repo.save(exercise)
    #expect(try await repo.all(includeArchived: false).map(\.name) == ["Rowing machine"])
    try await repo.delete(id: exercise.id)
    #expect(try await repo.all(includeArchived: true).map(\.name) == ["Ancien"])
}
