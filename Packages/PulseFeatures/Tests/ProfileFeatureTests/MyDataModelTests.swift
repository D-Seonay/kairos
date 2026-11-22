import Foundation
@testable import ProfileFeature
import PulseDomain
import PulseServices
import Testing

/// Un inspecteur qui rend ce que le test lui donne, ou échoue.
private struct ScriptedInspector: StoreInspector {
    var counts: [StoreTable: Int] = [:]
    var status: CloudAccountStatus = .unknown
    var failing = false

    func counts() async throws -> [StoreTable: Int] {
        if failing { throw MyDataFailure() }
        return counts
    }

    func cloudAccountStatus() async -> CloudAccountStatus { status }
}

/// Un exporteur qui rend deux adresses distinctes, ou échoue.
private struct ScriptedExporter: DataExporter {
    static let json = URL(fileURLWithPath: "/tmp/pulse.json")
    static let csv = URL(fileURLWithPath: "/tmp/pulse.zip")
    var failing = false

    func exportJSON() async throws -> URL {
        if failing { throw MyDataFailure() }
        return Self.json
    }

    func exportCSVArchive() async throws -> URL {
        if failing { throw MyDataFailure() }
        return Self.csv
    }
}

private struct MyDataFailure: Error {}

@MainActor
struct MyDataModelTests {
    private func model(inspector: ScriptedInspector = ScriptedInspector(),
                       exporter: ScriptedExporter = ScriptedExporter()) -> MyDataModel {
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
            inspector: inspector, exporter: exporter, eraser: SilentEraser(), notificationStatus: { .authorized },
            requestNotificationAuthorization: { true }, refreshHealth: {},
            appVersion: "1.0.2 (14)", privacyPolicyURL: nil, calendar: calendar, now: clock)
        return MyDataModel(environment: environment)
    }

    @Test func refreshReadsCountsAndCloudStatus() async {
        let model = model(inspector: ScriptedInspector(counts: [.workoutSessions: 12, .supplements: 3], status: .available))
        #expect(!model.hasRefreshed)
        #expect(model.counts.isEmpty)
        #expect(model.cloudStatus == nil)

        await model.refresh()

        #expect(model.hasRefreshed)
        #expect(model.counts == [.workoutSessions: 12, .supplements: 3])
        #expect(model.cloudStatus == .available)
        #expect(model.errorMessage == nil)
    }

    @Test func refreshFailureSaysSoAndStillMarksTheRead() async {
        let model = model(inspector: ScriptedInspector(status: .noAccount, failing: true))

        await model.refresh()

        #expect(model.errorMessage == "Pulse n'a pas pu lire tes données.")
        #expect(model.counts.isEmpty)
        #expect(model.cloudStatus == .noAccount)
        #expect(model.hasRefreshed)
    }

    @Test func exportSetsShareURL() async {
        let model = model()

        await model.exportJSON()
        #expect(model.shareURL == ScriptedExporter.json)
        #expect(!model.isBusy)

        await model.exportCSV()
        #expect(model.shareURL == ScriptedExporter.csv)
        #expect(model.errorMessage == nil)
    }

    @Test func exportFailureShowsMessage() async {
        let model = model(exporter: ScriptedExporter(failing: true))

        await model.exportJSON()

        #expect(model.shareURL == nil)
        #expect(model.errorMessage == "Pulse n'a pas pu exporter tes données.")
        #expect(!model.isBusy)
    }

    @Test func everyFailedExportCountsAsAFailure() async {
        let model = model(exporter: ScriptedExporter(failing: true))

        await model.exportJSON()
        await model.exportCSV()

        #expect(model.failureCount == 2, "La même erreur deux fois : deux annonces")
    }

    @Test func cloudTextCoversEveryStatus() {
        #expect(MyDataModel.cloudText(.noAccount) == "Aucun compte iCloud : tes données restent sur ce téléphone.")
        #expect(MyDataModel.cloudText(.restricted) == "Le compte iCloud est restreint : la synchronisation est coupée.")
        #expect(MyDataModel.cloudText(.unknown) == "État iCloud inconnu.")
        #expect(MyDataModel.cloudText(nil) == "Pas encore lu")
    }

    @Test func availableCloudSaysHealthStaysOnThePhone() {
        #expect(MyDataModel.cloudText(.available)
            == "Tes séances, compléments et scores se synchronisent avec ton compte iCloud. "
            + "Les données d'Apple Santé restent sur ce téléphone.")
    }
}
