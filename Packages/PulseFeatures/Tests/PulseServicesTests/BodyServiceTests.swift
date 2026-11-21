import Foundation
import PulseDomain
import PulseServices
import Testing

struct BodyServiceTests {
    private let now = TestClock.date("2026-11-20T12:00")
    private let measurements = InMemoryBodyMeasurementRepository()
    private let profiles = InMemoryProfileRepository()

    private var service: BodyService {
        let now = now
        return BodyService(measurements: measurements, profiles: profiles, calendar: TestClock.calendar, now: { now })
    }

    private func stored() async throws -> [BodyMeasurement] {
        try await measurements.measurements(from: .distantPast, to: .distantFuture)
    }

    private func measurement(_ weight: Double, at text: String, source: MeasurementSource) -> BodyMeasurement {
        BodyMeasurement(date: TestClock.date(text), weightKg: weight, source: source, createdAt: now, updatedAt: now)
    }

    @Test func addManualWritesAndSyncsProfile() async throws {
        try await profiles.save(UserProfile(weightKg: 80, createdAt: now, updatedAt: now))

        try await service.addManual(weightKg: 78.5, date: TestClock.date("2026-11-20T07:00"))

        let all = try await stored()
        #expect(all.count == 1 && all.first?.weightKg == 78.5 && all.first?.source == .manual)
        let profile = try #require(try await profiles.load())
        #expect(profile.weightKg == 78.5 && profile.updatedAt == now)
    }

    @Test func invalidWeightIsRejected() async throws {
        try await profiles.save(UserProfile(weightKg: 80, createdAt: now, updatedAt: now))

        for weight in [15.0, 500.0] {
            await #expect(throws: BodyServiceError.invalidWeight) {
                try await service.addManual(weightKg: weight, date: now)
            }
        }
        #expect(try await stored().isEmpty)
        #expect(try await profiles.load()?.weightKg == 80)
    }

    @Test func appleHealthMeasurementsCannotBeEdited() async throws {
        let imported = measurement(80, at: "2026-11-19T07:00", source: .appleHealth)
        try await measurements.save(imported)

        await #expect(throws: BodyServiceError.notManual) { try await service.updateManual(imported) }
        await #expect(throws: BodyServiceError.notManual) { try await service.deleteManual(id: imported.id) }
        // Même présentée comme manuelle, la mesure enregistrée est celle d'Apple Santé.
        var disguised = imported
        disguised.source = .manual
        await #expect(throws: BodyServiceError.notManual) { try await service.updateManual(disguised) }
        #expect(try await stored() == [imported])
    }

    @Test func updateAndDeleteManualSyncProfile() async throws {
        try await profiles.save(UserProfile(weightKg: 80, createdAt: now, updatedAt: now))
        let manual = measurement(79, at: "2026-11-19T07:00", source: .manual)
        try await measurements.save(manual)

        var edited = manual
        edited.weightKg = 77.44
        try await service.updateManual(edited)
        #expect(try await stored().first?.weightKg == 77.44)
        #expect(try await profiles.load()?.weightKg == 77.4)

        edited.weightKg = 10
        await #expect(throws: BodyServiceError.invalidWeight) { try await service.updateManual(edited) }
        #expect(try await stored().first?.weightKg == 77.44)

        try await service.deleteManual(id: manual.id)
        #expect(try await stored().isEmpty)
    }

    @Test func overviewListsNewestFirstAndFlagsHealthData() async throws {
        let old = measurement(81, at: "2026-11-15T07:00", source: .manual)
        let recent = measurement(80, at: "2026-11-19T07:00", source: .appleHealth)
        let outside = measurement(95, at: "2025-10-01T07:00", source: .appleHealth)
        for item in [old, recent, outside] { try await measurements.save(item) }

        let overview = try await service.overview()

        #expect(overview.measurements.map(\.id) == [recent.id, old.id])
        #expect(overview.hasAppleHealthData)
        #expect(overview.trend.current == 80.5)

        let manualOnly = InMemoryBodyMeasurementRepository([old])
        let local = BodyService(measurements: manualOnly, profiles: profiles, calendar: TestClock.calendar, now: { now })
        #expect(try await !local.overview().hasAppleHealthData)
    }
}
