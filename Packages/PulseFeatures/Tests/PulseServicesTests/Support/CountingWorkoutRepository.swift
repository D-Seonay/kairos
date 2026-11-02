import Foundation
import PulseDomain
import PulseServices

/// Un dépôt de séances qui délègue à `inner`, compte les sauvegardes et peut lever à la `failingAtSave`-ième.
actor CountingWorkoutRepository: WorkoutRepository {
    enum Failure: Error { case interrupted }

    private let inner: any WorkoutRepository
    private let failingAtSave: Int?
    private(set) var saveCount = 0

    init(inner: any WorkoutRepository = InMemoryWorkoutRepository(), failingAtSave: Int? = nil) {
        self.inner = inner
        self.failingAtSave = failingAtSave
    }

    func sessions(from: Date, to: Date) async throws -> [WorkoutSession] {
        try await inner.sessions(from: from, to: to)
    }

    func session(id: UUID) async throws -> WorkoutSession? {
        try await inner.session(id: id)
    }

    func save(_ session: WorkoutSession) async throws {
        saveCount += 1
        if saveCount == failingAtSave { throw Failure.interrupted }
        try await inner.save(session)
    }

    func delete(id: UUID) async throws {
        try await inner.delete(id: id)
    }

    func lastSets(for exercise: ExerciseReference) async throws -> [WorkoutSet] {
        try await inner.lastSets(for: exercise)
    }
}
