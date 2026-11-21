import Foundation
@testable import ProfileFeature
import PulseDomain
import PulseServices
import Testing

@MainActor
struct WeightModelTests {
    let profiles = InMemoryProfileRepository()
    let measurements = InMemoryBodyMeasurementRepository()
    let environment: ProfileEnvironment

    init() {
        let calendar = ProfileTestClock.calendar
        let clock: @Sendable () -> Date = { ProfileTestClock.now }
        let service = ProfileService(profiles: profiles, programs: InMemoryProgramRepository(), workouts: InMemoryWorkoutRepository(),
                                     recoveries: InMemoryRecoveryRepository(calendar: calendar),
                                     records: InMemoryPersonalRecordRepository(), userExercises: InMemoryUserExerciseRepository(),
                                     library: .bundled, calendar: calendar, now: clock)
        let body = BodyService(measurements: measurements, profiles: profiles, calendar: calendar, now: clock)
        let settings = SettingsService(profiles: profiles, now: clock) { _, _ in }
        environment = ProfileEnvironment(
            profile: service, body: body, settings: settings, healthCache: InMemoryHealthSampleCache(),
            inspector: SilentInspector(), exporter: SilentExporter(), eraser: SilentEraser(), notificationsDenied: { false },
            refreshHealth: {}, appVersion: "1.0.2 (14)", privacyPolicyURL: nil, calendar: calendar, now: clock)
    }

    /// Le modèle et le nombre d'appels à `onChanged`.
    private func model() -> (WeightModel, ChangeCounter) {
        let counter = ChangeCounter()
        let model = WeightModel(environment: environment) { counter.value += 1 }
        return (model, counter)
    }

    private func save(_ measurement: BodyMeasurement) async throws {
        try await measurements.save(measurement)
    }

    @Test func savingADraftAddsAManualWeighIn() async throws {
        let (model, changes) = model()
        await model.load()
        #expect(model.overview?.measurements.isEmpty == true)

        model.startNew()
        #expect(model.editor?.measurementID == nil)
        #expect(model.editor?.date == ProfileTestClock.now)
        model.editor?.weightText = " 78,4 "
        await model.save()

        let saved = try #require(model.overview?.measurements.first)
        #expect(model.overview?.measurements.count == 1)
        #expect(saved.weightKg == 78.4 && saved.source == .manual && saved.date == ProfileTestClock.now)
        #expect(model.overview?.trend.current == 78.4)
        #expect(model.editor == nil && model.errorMessage == nil)
        #expect(changes.value == 1, "La page Profil se recharge après l'écriture")

        model.startNew()
        model.editor?.weightText = "77.9"
        await model.save()
        #expect(model.overview?.measurements.count == 2, "Le point vaut la virgule")
    }

    @Test func invalidDraftShowsMessageAndKeepsSheet() async throws {
        let (model, changes) = model()
        await model.load()
        let message = "Entre un poids entre 20 et 400 kg."
        for text in ["12", "401", "", "  ", "abc", "78,4,1"] {
            model.startNew()
            model.editor?.weightText = text
            await model.save()

            #expect(model.errorMessage == message, "« \(text) »")
            #expect(model.editor?.weightText == text, "La feuille reste ouverte")
        }
        #expect(try await measurements.measurements(from: .distantPast, to: .distantFuture).isEmpty)
        #expect(changes.value == 0)

        model.closeEditor()
        #expect(model.editor == nil && model.errorMessage == nil)
    }

    @Test func editingKeepsTheMeasurementID() async throws {
        let weighed = ProfileTestClock.date(2026, 11, 18, hour: 7)
        let original = BodyMeasurement(date: weighed, weightKg: 78.4, source: .manual, createdAt: weighed, updatedAt: weighed)
        try await save(original)
        let (model, changes) = model()
        await model.load()

        model.edit(original)
        #expect(model.editor?.measurementID == original.id)
        #expect(model.editor?.weightText == "78,4")
        #expect(model.editor?.date == weighed)
        let earlier = ProfileTestClock.date(2026, 11, 17, hour: 8)
        model.editor?.weightText = "77,9"
        model.editor?.date = earlier
        await model.save()

        let stored = try await measurements.measurements(from: .distantPast, to: .distantFuture)
        #expect(stored.count == 1)
        #expect(stored.first?.id == original.id && stored.first?.weightKg == 77.9 && stored.first?.date == earlier)
        #expect(stored.first?.createdAt == weighed && stored.first?.source == .manual)
        #expect(model.overview?.measurements.first?.weightKg == 77.9)
        #expect(model.editor == nil && changes.value == 1)
    }

    @Test func deleteRemovesManualOnly() async throws {
        let weighed = ProfileTestClock.date(2026, 11, 18, hour: 7)
        let manual = BodyMeasurement(date: weighed, weightKg: 78.4, source: .manual, createdAt: weighed, updatedAt: weighed)
        let health = BodyMeasurement(date: weighed.addingTimeInterval(-3_600), weightKg: 78.9, source: .appleHealth,
                                     healthKitUUID: "sample-1", createdAt: weighed, updatedAt: weighed)
        try await save(manual)
        try await save(health)
        let (model, changes) = model()
        await model.load()

        model.edit(health)
        #expect(model.editor == nil, "Une mesure Apple Santé ne se modifie pas")
        await model.delete(health)
        #expect(changes.value == 0)
        await model.delete(manual)

        let stored = try await measurements.measurements(from: .distantPast, to: .distantFuture)
        #expect(stored.map(\.id) == [health.id])
        #expect(model.overview?.measurements.map(\.id) == [health.id])
        #expect(model.errorMessage == nil && changes.value == 1)
    }
}

struct WeightTextTests {
    let calendar = ProfileTestClock.calendar

    @Test func measurementRows() {
        let date = ProfileTestClock.date(2026, 11, 12, hour: 7)
        let weight = BodyMeasurement(date: date, weightKg: 78.4, source: .manual, createdAt: date, updatedAt: date)
        let fat = BodyMeasurement(date: date, bodyFatPercent: 17.5, source: .appleHealth, createdAt: date, updatedAt: date)
        let both = BodyMeasurement(date: date, weightKg: 80, bodyFatPercent: 18, source: .appleHealth, createdAt: date,
                                   updatedAt: date)
        #expect(ProfileText.measurement(weight) == "78,4 kg")
        #expect(ProfileText.measurement(fat) == "17,5 % de masse grasse")
        #expect(ProfileText.measurement(both) == "80 kg · 18 % de masse grasse")
        #expect(ProfileText.source(.manual) == "Saisie" && ProfileText.source(.appleHealth) == "Apple Santé")
    }

    @Test func trendCaptionDatesAStaleTrend() {
        let recent = ProfileTestClock.date(2026, 11, 18, hour: 7)
        let old = ProfileTestClock.date(2026, 10, 28, hour: 7)
        let fresh = WeightTrend.make(measurements: [BodyMeasurement(date: recent, weightKg: 78, source: .manual,
                                                                    createdAt: recent, updatedAt: recent)],
                                     now: ProfileTestClock.now, calendar: calendar)
        let stale = WeightTrend.make(measurements: [BodyMeasurement(date: old, weightKg: 78, source: .manual, createdAt: old,
                                                                    updatedAt: old)],
                                     now: ProfileTestClock.now, calendar: calendar)
        #expect(ProfileText.trendCaption(fresh, calendar: calendar, today: ProfileTestClock.now) == "tendance sur 7 jours")
        #expect(ProfileText.trendCaption(stale, calendar: calendar, today: ProfileTestClock.now) == "dernière mesure le 28 oct.")
    }
}

/// Compte les appels à `onChanged`.
@MainActor
final class ChangeCounter {
    var value = 0
}
