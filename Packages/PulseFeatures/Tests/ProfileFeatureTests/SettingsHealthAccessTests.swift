import Foundation
@testable import ProfileFeature
import PulseDomain
import PulseServices
import Testing

/// « Connecter Apple Santé » dans la section Apple Santé des Paramètres.
extension SettingsModelTests {
    /// Une source Apple Santé qui compte les demandes d'accès.
    private actor CountingHealthSource: HealthSampleSource {
        private(set) var requests = 0

        func requestAuthorization() async throws {
            requests += 1
        }

        func profileHints() async throws -> HealthProfileHints { HealthProfileHints() }

        func changes(of signal: NightSignal, since anchor: Data?, from start: Date) async throws -> HealthSampleChanges {
            throw UnavailableHealthSource.Failure.unavailable
        }
    }

    @Test func connectHealthIsOfferedUntilTheRequestIsMade() async throws {
        _ = try await storeProfile()
        let once = InMemoryOnceLog()
        let source = CountingHealthSource()
        let ran = ProfileTestClock.date(2026, 11, 20, hour: 11)
        let night = sample(.sleep, start: ProfileTestClock.date(2026, 11, 19, hour: 23),
                           end: ProfileTestClock.date(2026, 11, 20, hour: 7), fetchedAt: ran)
        let cache = cache
        let access = HealthAccess(source: source, cache: cache, once: once)
        let model = SettingsModel(environment: environment(refreshHealth: { try? await cache.insert([night]) },
                                                           healthAccess: access)) { _ in }
        // Avant la lecture, l'écran ne propose rien à tort.
        #expect(model.healthAccessRequested)
        await model.load()
        #expect(!model.healthAccessRequested)

        await model.connectHealth()

        #expect(await source.requests == 1)
        #expect(once.hasHappened(.healthAccessRequest))
        #expect(model.healthAccessRequested && !model.isConnectingHealth && model.errorMessage == nil)
        // Le passage du jour a couru, comme au retour au premier plan : l'état relu montre la nuit qu'il vient de lire.
        #expect(model.health?.lastRead == ran)
    }

    @Test func aFailedHealthRequestSaysSoAndKeepsTheOffer() async throws {
        _ = try await storeProfile()
        let once = InMemoryOnceLog()
        let access = HealthAccess(source: UnavailableHealthSource(), cache: cache, once: once)
        let model = SettingsModel(environment: environment(healthAccess: access)) { _ in }
        await model.load()

        await model.connectHealth()

        #expect(model.errorMessage == "Pulse n'a pas pu accéder à Apple Santé.")
        #expect(!model.healthAccessRequested && !model.isConnectingHealth)
        #expect(!once.hasHappened(.healthAccessRequest))
    }

    /// La demande déjà faite (à l'onboarding, ou prouvée par une donnée lue), ou aucun service d'accès : le pied de section
    /// renvoie à Santé → Partage, sans bouton.
    @Test func noOfferOnceTheRequestWasMade() async throws {
        _ = try await storeProfile()
        let remembered = InMemoryOnceLog([.healthAccessRequest])
        let asked = SettingsModel(environment: environment(
            healthAccess: HealthAccess(source: CountingHealthSource(), cache: cache, once: remembered))) { _ in }
        await asked.load()
        #expect(asked.healthAccessRequested)

        let plain = SettingsModel(environment: environment()) { _ in }
        await plain.load()
        #expect(plain.healthAccessRequested)
    }
}
