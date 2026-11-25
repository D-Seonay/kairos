import Foundation
import PulseDomain
import PulseServices
import Testing

/// Un dépôt de profil où les deux premières lectures se croisent : chacune attend que l'autre ait lu avant de rendre son profil,
/// comme deux écritures « lecture, modification, enregistrement » qui s'entrelacent. Au bout d'une seconde, une lecture seule
/// repart quand même (aucun blocage si une seule écriture lit). `update` passe tel quel au dépôt en mémoire.
private actor CrossingProfileRepository: ProfileRepository {
    let inner = InMemoryProfileRepository()
    private var reads = 0
    private var waiting: [CheckedContinuation<Void, Never>] = []

    func load() async throws -> UserProfile? {
        let profile = try await inner.load()
        reads += 1
        if reads >= 2 {
            releaseAll()
        } else {
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(1))
                await self?.releaseAll()
            }
            await withCheckedContinuation { waiting.append($0) }
        }
        return profile
    }

    func save(_ profile: UserProfile) async throws {
        try await inner.save(profile)
    }

    func delete(id: UUID) async throws {
        try await inner.delete(id: id)
    }

    @discardableResult
    func update(_ transform: @Sendable (inout UserProfile) throws -> Void) async throws -> ProfileUpdate? {
        try await inner.update(transform)
    }

    private func releaseAll() {
        let toWake = waiting
        waiting = []
        toWake.forEach { $0.resume() }
    }
}

/// Deux écritures de champs différents du profil qui se croisent gardent chacune leur champ (issue #72).
struct ProfileUpdateCrossingTests {
    private let now = TestClock.date("2026-11-21T12:00")

    @Test func crossingWritesOfDifferentFieldsAreBothKept() async throws {
        let profiles = CrossingProfileRepository()
        try await profiles.save(UserProfile(createdAt: now, updatedAt: now))
        let weighIn = BodyMeasurement(date: now, weightKg: 75, source: .manual, createdAt: now, updatedAt: now)
        let measurements = InMemoryBodyMeasurementRepository([weighIn])
        let now = now
        let settings = SettingsService(profiles: profiles, now: { now }, onChange: { _, _ in })

        async let rename: UserProfile = settings.update { $0.firstName = "Léa" }
        async let weight: Void = ProfileWeightSync.apply(measurements: measurements, profiles: profiles, now: now,
                                                         calendar: TestClock.calendar)
        _ = try await (rename, weight)

        let stored = try #require(try await profiles.inner.load())
        #expect(stored.firstName == "Léa")
        #expect(stored.weightKg == 75)
    }
}
