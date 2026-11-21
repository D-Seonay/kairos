import Foundation
import PulseDomain
import PulseServices
import Testing

/// Garde les appels de `onChange` ; l'actor rend la fermeture `@Sendable` sûre.
private actor ChangeLog {
    private(set) var calls: [(old: UserProfile, new: UserProfile)] = []
    func record(_ old: UserProfile, _ new: UserProfile) { calls.append((old, new)) }
}

struct SettingsServiceTests {
    private let now = TestClock.date("2026-11-21T12:00")
    private let earlier = TestClock.date("2026-11-01T12:00")
    private let profiles = InMemoryProfileRepository()
    private let log = ChangeLog()

    private var service: SettingsService {
        let now = now
        let log = log
        return SettingsService(profiles: profiles, now: { now }, onChange: { old, new in await log.record(old, new) })
    }

    private func seed(_ profile: UserProfile? = nil) async throws -> UserProfile {
        let value = profile ?? UserProfile(createdAt: earlier, updatedAt: earlier)
        try await profiles.save(value)
        return value
    }

    @Test func loadWithoutProfileThrows() async {
        await #expect(throws: SettingsError.noProfile) { try await service.load() }
        await #expect(throws: SettingsError.noProfile) { try await service.update { $0.firstName = "A" } }
    }

    @Test func updateWritesAndNotifiesOnce() async throws {
        let original = try await seed()

        let result = try await service.update { $0.firstName = "Mathéo" }

        let stored = try #require(try await profiles.load())
        #expect(stored.firstName == "Mathéo" && stored.updatedAt == now)
        #expect(result == stored)
        let calls = await log.calls
        #expect(calls.count == 1 && calls.first?.old == original && calls.first?.new == stored)
    }

    @Test func unchangedProfileIsNotWritten() async throws {
        let original = try await seed(UserProfile(firstName: "Mathéo", createdAt: earlier, updatedAt: earlier))

        let result = try await service.update { $0.firstName = "Mathéo" }

        #expect(result == original)
        #expect(try await profiles.load() == original)
        #expect(await log.calls.isEmpty)
    }

    @Test func invalidChangesAreRejected() async throws {
        let original = try await seed()
        let cases: [(@Sendable (inout UserProfile) -> Void, SettingsError)] = [
            ({ $0.heightCm = 0 }, .invalidHeight),
            ({ $0.upperIncrementKg = -2.5 }, .invalidIncrement),
            ({ $0.lowerIncrementKg = 0 }, .invalidIncrement),
            ({ $0.defaultRestSeconds = 75 }, .invalidRest),
            ({ $0.morningScoreDeadlineMinutes = 13 * 60 }, .invalidDeadline),
            ({ $0.availablePlatesKg = [] }, .invalidPlates),
            ({ $0.availablePlatesKg = [0, -5] }, .invalidPlates),
            ({ $0.barWeightKg = 0 }, .invalidPlates)
        ]

        for (change, error) in cases {
            await #expect(throws: error) { try await service.update(change) }
            #expect(try await profiles.load() == original)
        }
        #expect(await log.calls.isEmpty)
    }

    @Test func validEdgeValuesAreAccepted() async throws {
        try await seed()

        let result = try await service.update {
            $0.heightCm = 180
            $0.defaultRestSeconds = 180
            $0.morningScoreDeadlineMinutes = SettingsService.deadlineRange.lowerBound
        }

        #expect(result.heightCm == 180 && result.defaultRestSeconds == 180 && result.morningScoreDeadlineMinutes == 360)
        let cleared = try await service.update { $0.heightCm = nil; $0.morningScoreDeadlineMinutes = nil }
        #expect(cleared.heightCm == nil && cleared.morningScoreDeadlineMinutes == nil)
    }

    @Test func firstNameIsTrimmedAndEmptyBecomesNil() async throws {
        try await seed()

        let trimmed = try await service.update { $0.firstName = "  Mathéo \n" }
        #expect(trimmed.firstName == "Mathéo")

        let emptied = try await service.update { $0.firstName = "   " }
        #expect(emptied.firstName == nil)
        #expect(try await profiles.load()?.firstName == nil)
    }

    @Test func platesAreSortedDescending() async throws {
        try await seed()

        let result = try await service.update { $0.availablePlatesKg = [2.5, 0, 20, 1.25, 10] }

        #expect(result.availablePlatesKg == [20, 10, 2.5, 1.25])
    }
}
