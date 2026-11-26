import Foundation
import PulseDomain
import PulseServices
import Synchronization
import Testing

/// La demande d'accès à Apple Santé faite après l'onboarding (Paramètres, bannière du check-in).
struct HealthAccessTests {
    private struct Refused: Error {}

    /// Une source qui compte les demandes d'accès, et peut les faire échouer.
    private final class CountingSource: HealthSampleSource {
        private let count = Mutex(0)
        private let fails: Bool

        init(fails: Bool = false) {
            self.fails = fails
        }

        var requests: Int { count.withLock { $0 } }

        func requestAuthorization() async throws {
            count.withLock { $0 += 1 }
            if fails { throw Refused() }
        }

        func profileHints() async throws -> HealthProfileHints { HealthProfileHints() }

        func changes(of signal: NightSignal, since anchor: Data?, from start: Date) async throws -> HealthSampleChanges {
            throw Refused()
        }
    }

    /// Compte les suites données à une demande (la relance des observateurs d'Apple Santé, dans l'app).
    private final class FollowUps: Sendable {
        private let count = Mutex(0)

        var value: Int { count.withLock { $0 } }

        func add() {
            count.withLock { $0 += 1 }
        }
    }

    private let cache = InMemoryHealthSampleCache()
    private let once = InMemoryOnceLog()
    private let followUps = FollowUps()

    private func access(_ source: CountingSource) -> HealthAccess {
        HealthAccess(source: source, cache: cache, once: once, afterRequest: { [followUps] in followUps.add() })
    }

    @Test func nothingWasRequestedOnAFreshInstall() async {
        #expect(await access(CountingSource()).wasRequested() == false)
        #expect(!once.hasHappened(.healthAccessRequest))
    }

    @Test func aRequestIsRememberedAndFollowedUp() async throws {
        let source = CountingSource()
        let access = access(source)
        try await access.request()
        #expect(source.requests == 1)
        #expect(once.hasHappened(.healthAccessRequest))
        #expect(followUps.value == 1)
        #expect(await access.wasRequested())
    }

    @Test func aFailedRequestIsNotRemembered() async {
        let source = CountingSource(fails: true)
        let access = access(source)
        await #expect(throws: Refused.self) { try await access.request() }
        #expect(source.requests == 1)
        #expect(!once.hasHappened(.healthAccessRequest))
        #expect(followUps.value == 0)
        #expect(await access.wasRequested() == false)
    }

    /// Une installation d'avant ce réglage : la demande a été faite à l'onboarding sans être retenue. Une donnée déjà lue le
    /// prouve, et la demande est retenue pour la suite.
    @Test func cachedHealthDataProvesAnEarlierRequest() async throws {
        let night = Date(timeIntervalSince1970: 1_800_000_000)
        try await cache.insert([CachedHealthSample(kind: .restingHeartRate, start: night, end: night, value: 52, fetchedAt: night)])
        #expect(await access(CountingSource()).wasRequested())
        #expect(once.hasHappened(.healthAccessRequest))
    }

    /// Une course ou une pesée du cache ne prouve rien : Pulse relit celles qu'il a écrites lui-même dans Apple Santé, sans
    /// avoir jamais demandé à lire les nuits.
    @Test func aCachedWorkoutOrWeighInProvesNothing() async throws {
        let morning = Date(timeIntervalSince1970: 1_800_000_000)
        try await cache.insert([
            CachedHealthSample(kind: .run, start: morning, end: morning.addingTimeInterval(1_800), fetchedAt: morning),
            CachedHealthSample(kind: .bodyMass, start: morning, end: morning, value: 74, fetchedAt: morning)
        ])
        #expect(await access(CountingSource()).wasRequested() == false)
        #expect(!once.hasHappened(.healthAccessRequest))
    }
}
