import Foundation
import PulseDomain
import PulseServices
import Testing

struct InMemoryRepositoriesTests {
    private let day = TestClock.date("2026-11-02T00:00")

    private func recovery(score: Double, at date: Date, createdAt: Date) -> DailyRecovery {
        DailyRecovery(day: date, score: score, category: .optimal, isEstimated: false, calibration: .ready,
                      createdAt: createdAt, updatedAt: createdAt)
    }

    @Test func recoverySaveKeepsOneRecordPerLocalDay() async throws {
        let repository = InMemoryRecoveryRepository(calendar: TestClock.calendar)
        let first = recovery(score: 60, at: TestClock.date("2026-11-02T08:30"), createdAt: day)
        let second = recovery(score: 80, at: TestClock.date("2026-11-02T21:00"), createdAt: TestClock.date("2026-11-03T00:00"))
        try await repository.save(first)
        try await repository.save(second)
        let stored = try await repository.dailyRecoveries(from: day, to: TestClock.date("2026-11-03T00:00"))
        #expect(stored.count == 1)
        #expect(stored.first?.day == day && stored.first?.score == 80)
        #expect(stored.first?.id == first.id && stored.first?.createdAt == day)
    }

    @Test func profileLoadReturnsTheOldestAndDeleteIsLogical() async throws {
        let repository = InMemoryProfileRepository()
        let older = UserProfile(createdAt: day, updatedAt: day)
        let newer = UserProfile(createdAt: TestClock.date("2026-11-03T00:00"), updatedAt: day)
        try await repository.save(newer)
        try await repository.save(older)
        #expect(try await repository.load()?.id == older.id)
        try await repository.delete(id: older.id)
        #expect(try await repository.load()?.id == newer.id)
    }

    @Test func programListingsExcludeDeletedAndArchived() async throws {
        let repository = InMemoryProgramRepository()
        let active = Program(name: "A", sessionsPerWeek: 3, weekLayout: [], days: [], createdAt: day, updatedAt: day)
        let archived = Program(name: "B", sessionsPerWeek: 3, weekLayout: [], isArchived: true, days: [], createdAt: day, updatedAt: day)
        let removed = Program(name: "C", sessionsPerWeek: 3, weekLayout: [], days: [], createdAt: day, updatedAt: day)
        for program in [active, archived, removed] { try await repository.save(program) }
        try await repository.delete(id: removed.id)
        #expect(try await repository.programs(includeArchived: false).map(\.id) == [active.id])
        #expect(try await repository.programs(includeArchived: true).count == 2)
        #expect(try await repository.program(id: removed.id) == nil)
        var renamed = active
        renamed.name = "A2"
        try await repository.save(renamed)
        #expect(try await repository.program(id: active.id)?.name == "A2")
    }
}
