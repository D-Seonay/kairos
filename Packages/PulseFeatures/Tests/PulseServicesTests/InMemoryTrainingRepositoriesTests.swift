import Foundation
import PulseDomain
import PulseServices
import Testing

struct InMemoryTrainingRepositoriesTests {
    private func userExercise(_ name: String, archived: Bool = false) -> UserExercise {
        UserExercise(name: name, primaryMuscle: .biceps, secondaryMuscles: [], equipment: .cable, pattern: .elbowFlexion,
                     region: .upper, isUnilateral: false, defaultIncrementKg: 2.5, defaultRestSeconds: 60, isArchived: archived,
                     createdAt: .t0, updatedAt: .t0)
    }

    @Test func userExercisesSaveReplaceAndDeleteLogically() async throws {
        let repository = InMemoryUserExerciseRepository()
        var curl = userExercise("Curl poulie")
        let archived = userExercise("Ancien", archived: true)
        try await repository.save(curl)
        try await repository.save(archived)
        curl.name = "Curl poulie basse"
        try await repository.save(curl)
        #expect(try await repository.all(includeArchived: false).map(\.name) == ["Curl poulie basse"])
        #expect(try await repository.all(includeArchived: true).count == 2)
        try await repository.delete(id: curl.id)
        #expect(try await repository.all(includeArchived: true).map(\.id) == [archived.id])
    }

    @Test func settingsSaveReplacesTheActiveRecordOfTheSameExercise() async throws {
        let repository = InMemoryExerciseSettingsRepository()
        let pushdown = ExerciseReference.content(id: "triceps-pushdown-cable")
        let first = ExerciseSettings(exercise: pushdown, incrementKg: 1.25, createdAt: .t0, updatedAt: .t0)
        try await repository.save(first)
        let replacement = ExerciseSettings(exercise: pushdown, incrementKg: 2, warmupSetCount: 1, createdAt: .t0, updatedAt: .t0)
        try await repository.save(replacement)
        let stored = try await repository.settings(for: pushdown)
        #expect(stored?.id == first.id && stored?.incrementKg == 2 && stored?.warmupSetCount == 1)
        #expect(try await repository.all().count == 1)
        #expect(try await repository.settings(for: .content(id: "pec-deck-machine")) == nil)
    }

    private func record(_ kind: RecordKind, value: Double, weight: Double?, set: UUID?, date: Date = .t0) -> PersonalRecord {
        PersonalRecord(exercise: .content(id: "bench-press-barbell"), exerciseName: "Développé couché", kind: kind, value: value,
                       weightKg: weight, date: date, setID: set, createdAt: .t0, updatedAt: .t0)
    }

    @Test func replaceAllKeepsMatchingRecordsRetiresAbsentOnesAndInsertsNewOnes() async throws {
        let repository = InMemoryPersonalRecordRepository()
        let (setA, setB) = (UUID(), UUID())
        let kept = record(.maxWeight, value: 80, weight: 80, set: setA)
        let dropped = record(.maxWeight, value: 60, weight: 60, set: setB)
        try await repository.replaceAll(with: [kept, dropped])
        let recalculated = record(.maxWeight, value: 80, weight: 80, set: setA, date: TestClock.date("2026-11-09T08:00"))
        let added = record(.estimatedOneRepMax, value: 100, weight: nil, set: setA)
        try await repository.replaceAll(with: [recalculated, added])
        let stored = try await repository.records(for: nil)
        #expect(stored.count == 2)
        let survivor = try #require(stored.first { $0.kind == .maxWeight })
        #expect(survivor.id == kept.id && survivor.date == recalculated.date)
        #expect(stored.contains { $0.id == added.id })
        #expect(!stored.contains { $0.id == dropped.id })
    }

    @Test func recordsFilterByExerciseNewestFirstAndDeleteLogically() async throws {
        let repository = InMemoryPersonalRecordRepository()
        let older = record(.maxWeight, value: 70, weight: 70, set: UUID())
        let newer = record(.maxWeight, value: 75, weight: 75, set: UUID(), date: TestClock.date("2026-11-09T08:00"))
        var other = record(.maxWeight, value: 50, weight: 50, set: UUID())
        other.exercise = .content(id: "pec-deck-machine")
        for item in [older, newer, other] { try await repository.save(item) }
        #expect(try await repository.records(for: .content(id: "bench-press-barbell")).map(\.id) == [newer.id, older.id])
        #expect(try await repository.records(for: nil).count == 3)
        try await repository.delete(id: newer.id)
        #expect(try await repository.records(for: nil).map(\.id).contains(newer.id) == false)
    }
}
