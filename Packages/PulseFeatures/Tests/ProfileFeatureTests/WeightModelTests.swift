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
            inspector: SilentInspector(), exporter: SilentExporter(), eraser: SilentEraser(), notificationStatus: { .authorized },
            requestNotificationAuthorization: { true },
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
        #expect(model.editor == nil && model.editorError == nil && model.errorMessage == nil)
        #expect(changes.value == 1, "La page Profil se recharge après l'écriture")

        model.startNew()
        model.editor?.weightText = "77.9"
        await model.save()
        #expect(model.overview?.measurements.count == 2, "Le point vaut la virgule")
    }

    @Test func invalidDraftShowsMessageAndKeepsSheet() async throws {
        let (model, changes) = model()
        await model.load()
        let message = "Entre un poids entre 20 et 400 kilos."
        for text in ["12", "401", "", "  ", "abc", "78,4,1"] {
            model.startNew()
            model.editor?.weightText = text
            await model.save()

            #expect(model.editorError == message, "« \(text) »")
            #expect(model.errorMessage == nil, "L'erreur de la feuille reste dans la feuille")
            #expect(model.editor?.weightText == text, "La feuille reste ouverte")
        }
        #expect(try await measurements.measurements(from: .distantPast, to: .distantFuture).isEmpty)
        #expect(changes.value == 0)

        model.closeEditor()
        #expect(model.editor == nil && model.editorError == nil)
    }

    @Test func futureDateShowsMessageAndKeepsSheet() async throws {
        let (model, changes) = model()
        await model.load()
        model.startNew()
        model.editor?.weightText = "78,4"
        model.editor?.date = ProfileTestClock.now.addingTimeInterval(60)
        await model.save()

        #expect(model.editorError == "Choisis une date passée.")
        #expect(model.editor != nil && changes.value == 0)
        #expect(try await measurements.measurements(from: .distantPast, to: .distantFuture).isEmpty)

        model.editor?.date = ProfileTestClock.now
        await model.save()
        #expect(model.editor == nil && model.editorError == nil && changes.value == 1, "Maintenant est accepté")
    }

    @Test func failedSaveKeepsSheetAndSkipsReload() async throws {
        let failing = FailingSaveMeasurements()
        let calendar = ProfileTestClock.calendar
        var environment = environment
        environment.body = BodyService(measurements: failing, profiles: profiles, calendar: calendar,
                                       now: { ProfileTestClock.now })
        let changes = ChangeCounter()
        let model = WeightModel(environment: environment) { changes.value += 1 }
        await model.load()
        model.startNew()
        model.editor?.weightText = "78,4"
        await model.save()

        #expect(model.editorError == "Pulse n'a pas pu enregistrer ta pesée.")
        #expect(model.errorMessage == nil)
        #expect(model.editor?.weightText == "78,4", "La feuille reste ouverte")
        #expect(changes.value == 0)
    }

    @Test func dismissingClearsTheSheetErrorOnlyOnceClosed() async throws {
        let (model, _) = model()
        await model.load()
        model.startNew()
        model.editor?.weightText = "12"
        await model.save()
        model.editorDismissed()
        #expect(model.editorError != nil, "Une feuille encore ouverte garde son message")

        model.editor = nil
        model.editorDismissed()
        #expect(model.editorError == nil)
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

/// Un dépôt de mesures dont chaque écriture échoue.
actor FailingSaveMeasurements: BodyMeasurementRepository {
    struct Failure: Error {}

    func measurements(from: Date, to: Date) async throws -> [BodyMeasurement] { [] }
    func save(_ measurement: BodyMeasurement) async throws { throw Failure() }
    func delete(id: UUID) async throws { throw Failure() }
}

/// Compte les appels à `onChanged`.
@MainActor
final class ChangeCounter {
    var value = 0
}

@MainActor
struct WeightModelFailureTests {
    @Test func repeatedIdenticalSheetErrorsCountAgain() async throws {
        let calendar = ProfileTestClock.calendar
        let clock: @Sendable () -> Date = { ProfileTestClock.now }
        let profiles = InMemoryProfileRepository()
        let service = ProfileService(profiles: profiles, programs: InMemoryProgramRepository(), workouts: InMemoryWorkoutRepository(),
                                     recoveries: InMemoryRecoveryRepository(calendar: calendar),
                                     records: InMemoryPersonalRecordRepository(), userExercises: InMemoryUserExerciseRepository(),
                                     library: .bundled, calendar: calendar, now: clock)
        let environment = ProfileEnvironment(
            profile: service, body: BodyService(measurements: InMemoryBodyMeasurementRepository(), profiles: profiles,
                                                calendar: calendar, now: clock),
            settings: SettingsService(profiles: profiles, now: clock) { _, _ in }, healthCache: InMemoryHealthSampleCache(),
            inspector: SilentInspector(), exporter: SilentExporter(), eraser: SilentEraser(), notificationStatus: { .authorized },
            requestNotificationAuthorization: { true }, refreshHealth: {}, appVersion: "1.0.2 (14)", privacyPolicyURL: nil,
            calendar: calendar, now: clock)
        let model = WeightModel(environment: environment) {}
        await model.load()
        model.startNew()
        model.editor?.weightText = "12"
        await model.save()
        let first = model.editorFailureCount
        await model.save()
        #expect(model.editorError == WeightModel.invalidWeightMessage)
        #expect(model.editorFailureCount == first + 1, "La même erreur, annoncée une seconde fois")
        #expect(first == 1 && model.failureCount == 0, "Les erreurs de la feuille ne touchent pas celles de l'écran")
    }
}
