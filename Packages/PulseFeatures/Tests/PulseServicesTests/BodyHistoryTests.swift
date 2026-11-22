import Foundation
import PulseDomain
@testable import PulseServices
import Testing

/// Une source de poids et de masse grasse qui rend, par signal, la réponse préparée et note les ancres reçues.
private actor ScriptedBodySource: HealthBodySource {
    var samples: [BodySignal: [CachedHealthSample]] = [:]
    var deleted: [String] = []
    /// Vrai : la source rend toujours une lecture complète, comme quand l'ancre stockée est illisible.
    var alwaysFullRead = false
    private var anchors: [BodySignal: [Data?]] = [:]

    func anchorsSeen(for signal: BodySignal) -> [Data?] {
        anchors[signal] ?? []
    }

    func set(_ samples: [BodySignal: [CachedHealthSample]], deleted: [String] = []) {
        self.samples = samples
        self.deleted = deleted
    }

    func set(alwaysFullRead: Bool) {
        self.alwaysFullRead = alwaysFullRead
    }

    func bodyChanges(of signal: BodySignal, since anchor: Data?, from start: Date) async throws -> HealthSampleChanges {
        anchors[signal, default: []].append(anchor)
        return HealthSampleChanges(kind: signal.kind, added: samples[signal] ?? [], deletedHealthKitUUIDs: deleted,
                                   anchor: Data("a".utf8), isFullRead: anchor == nil || alwaysFullRead)
    }
}

struct BodyHistoryTests {
    private let source = ScriptedBodySource()
    private let cache = InMemoryHealthSampleCache()
    private let measurements = InMemoryBodyMeasurementRepository()
    private let profiles = InMemoryProfileRepository()
    private let windows = InMemoryHealthReadWindowStore()
    private let now = TestClock.date("2026-11-20T12:00")

    private var history: BodyHistory {
        BodyHistory(source: source, cache: cache, measurements: measurements, profiles: profiles, windows: windows,
                    calendar: TestClock.calendar)
    }

    private func sample(_ signal: BodySignal, _ uuid: String, _ value: Double, at text: String) -> CachedHealthSample {
        let start = TestClock.date(text)
        return CachedHealthSample(kind: signal.kind, start: start, end: start, value: value, healthKitUUID: uuid, fetchedAt: start)
    }

    private func stored() async throws -> [BodyMeasurement] {
        try await measurements.measurements(from: .distantPast, to: .distantFuture)
    }

    private var threeSamples: [BodySignal: [CachedHealthSample]] {
        [.bodyMass: [sample(.bodyMass, "w1", 78.4, at: "2026-11-18T07:30"), sample(.bodyMass, "w2", 78.1, at: "2026-11-19T07:30")],
         .bodyFat: [sample(.bodyFat, "f1", 17.5, at: "2026-11-19T07:30")]]
    }

    @Test func weightSamplesBecomeMeasurements() async throws {
        await source.set(threeSamples)

        #expect(await history.refresh(now: now))
        let all = try await stored()
        #expect(all.count == 3)
        #expect(all.allSatisfy { $0.source == .appleHealth })
        let weights = all.filter { $0.weightKg != nil }
        #expect(weights.map(\.weightKg) == [78.4, 78.1] && weights.map(\.healthKitUUID) == ["w1", "w2"])
        #expect(weights.allSatisfy { $0.bodyFatPercent == nil })
        let fat = try #require(all.first { $0.bodyFatPercent != nil })
        #expect(fat.bodyFatPercent == 17.5 && fat.weightKg == nil && fat.healthKitUUID == "f1")
        #expect(fat.date == TestClock.date("2026-11-19T07:30"))
    }

    @Test func secondPassKeepsIdsAndChangesNothing() async throws {
        await source.set(threeSamples)
        await history.refresh(now: now)
        let first = try await stored()

        #expect(await !history.refresh(now: now))
        #expect(try await stored() == first)
    }

    @Test func deletedSampleRemovesItsMeasurement() async throws {
        await source.set(threeSamples)
        await history.refresh(now: now)
        await source.set([:], deleted: ["w1"])

        #expect(await history.refresh(now: now))
        #expect(try await stored().compactMap(\.healthKitUUID).sorted() == ["f1", "w2"])
    }

    @Test func manualMeasurementsAreNeverTouched() async throws {
        let manual = BodyMeasurement(date: TestClock.date("2026-11-18T21:00"), weightKg: 79, source: .manual,
                                     createdAt: now, updatedAt: now)
        try await measurements.save(manual)
        await source.set(threeSamples)
        await history.refresh(now: now)
        #expect(try await stored().count == 4)

        await source.set([:], deleted: ["w1", "w2", "f1"])
        #expect(await history.refresh(now: now))
        #expect(try await stored() == [manual])
    }

    @Test func emptyFullReadKeepsMeasurements() async throws {
        await source.set(threeSamples)
        await history.refresh(now: now)
        windows.save(days: 60, for: .bodyMass)
        await source.set([:])

        #expect(await !history.refresh(now: now))
        #expect(try await stored().count == 3)
        #expect(windows.days(for: .bodyMass) == 60)
        // Retentée à la passe suivante : toujours en lecture complète, sans ancre.
        await history.refresh(now: now)
        #expect(await source.anchorsSeen(for: .bodyMass).suffix(2) == [nil, nil])
        #expect(try await stored().count == 3)
    }

    @Test func emptyFullReadWithCurrentWindowKeepsMeasurements() async throws {
        // Fenêtre à jour, mais l'ancre est illisible : la source relit tout et ne rend rien (accès révoqué).
        await source.set(threeSamples)
        await history.refresh(now: now)
        #expect(windows.days(for: .bodyMass) == BodyHistory.historyDays)
        await source.set([:])
        await source.set(alwaysFullRead: true)

        #expect(await !history.refresh(now: now))
        #expect(try await stored().count == 3)
        #expect(try await cache.samples(kind: .bodyMass, from: .distantPast, to: .distantFuture).count == 2)
    }

    @Test func syncedMeasurementsSurviveAnEmptyFullReadWithAnEmptyCache() async throws {
        // Second appareil ou réinstallation : les mesures importées arrivent par iCloud, le cache local est vide.
        var weight = BodyMeasurement(date: TestClock.date("2026-11-18T07:30"), weightKg: 78.4, source: .appleHealth,
                                     createdAt: now, updatedAt: now)
        weight.healthKitUUID = "w1"
        var fat = BodyMeasurement(date: TestClock.date("2026-11-19T07:30"), bodyFatPercent: 17.5, source: .appleHealth,
                                  createdAt: now, updatedAt: now)
        fat.healthKitUUID = "f1"
        try await measurements.save(weight)
        try await measurements.save(fat)
        await source.set([:])

        #expect(await !history.refresh(now: now))
        #expect(try await stored().count == 2)
        #expect(windows.days(for: .bodyMass) == nil && windows.days(for: .bodyFat) == nil)
    }

    @Test func measurementsSharingAHealthKitUUIDKeepTheOldest() async throws {
        var oldest = BodyMeasurement(date: TestClock.date("2026-11-18T07:30"), weightKg: 78.4, source: .appleHealth,
                                     createdAt: TestClock.date("2026-11-18T08:00"), updatedAt: now)
        oldest.healthKitUUID = "w1"
        var copy = oldest
        copy.id = UUID()
        copy.createdAt = TestClock.date("2026-11-19T08:00")
        try await measurements.save(copy)
        try await measurements.save(oldest)
        await source.set([.bodyMass: [sample(.bodyMass, "w1", 78.4, at: "2026-11-18T07:30")]])

        #expect(await history.refresh(now: now))
        let all = try await stored()
        #expect(all.count == 1)
        #expect(all.first?.id == oldest.id)
    }

    @Test func changedSampleUpdatesItsMeasurementAndKeepsItsID() async throws {
        await source.set([.bodyMass: [sample(.bodyMass, "w1", 78.4, at: "2026-11-18T07:30")]])
        await history.refresh(now: now)
        let first = try #require(try await stored().first)

        await source.set([.bodyMass: [sample(.bodyMass, "w1", 78.9, at: "2026-11-18T07:30")]])
        let later = TestClock.date("2026-11-21T09:00")
        #expect(await history.refresh(now: later))
        let updated = try #require(try await stored().first)
        #expect(updated.id == first.id && updated.createdAt == first.createdAt)
        #expect(updated.weightKg == 78.9 && updated.updatedAt == later)
    }

    @Test func firstReadWithEmptyCacheIsRetained() async throws {
        await source.set([:])
        await history.refresh(now: now)
        #expect(windows.days(for: .bodyMass) == BodyHistory.historyDays)
    }

    @Test func importedWeightNeverEntersTheProfile() async throws {
        try await profiles.save(UserProfile(weightKg: 80, createdAt: now, updatedAt: now))
        await source.set([.bodyMass: [sample(.bodyMass, "w1", 77.9, at: "2026-11-19T07:30")]])

        #expect(await history.refresh(now: now))
        // Seules des pesées Apple Santé existent : le profil, synchronisé par iCloud, n'en garde rien.
        #expect(try await profiles.load()?.weightKg == nil)
    }

    @Test func profileWeightIsSyncedOnEveryPassEvenWithoutChange() async throws {
        let manual = BodyMeasurement(date: TestClock.date("2026-11-19T21:00"), weightKg: 79.2, source: .manual,
                                     createdAt: now, updatedAt: now)
        try await measurements.save(manual)
        try await profiles.save(UserProfile(weightKg: 80, createdAt: now, updatedAt: now))
        await source.set([:])

        #expect(await history.refresh(now: now) == false)
        #expect(try await profiles.load()?.weightKg == 79.2)
    }

    @Test func missingProfileDoesNotMakeRefreshFail() async throws {
        await source.set([.bodyMass: [sample(.bodyMass, "w1", 77.9, at: "2026-11-19T07:30")]])

        #expect(await history.refresh(now: now))
        #expect(try await profiles.load() == nil)
    }
}
