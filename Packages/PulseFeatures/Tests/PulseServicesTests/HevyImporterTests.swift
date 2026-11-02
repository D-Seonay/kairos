import Foundation
import PulseContent
import PulseDomain
import PulseServices
import Synchronization
import Testing

struct HevyImporterTests {
    private let workouts = InMemoryWorkoutRepository()
    private let userExercises = InMemoryUserExerciseRepository()
    private let records = InMemoryPersonalRecordRepository()
    private let mappings = InMemoryHevyMappingStore()
    private let data = Data(HevyFixtures.csv.utf8)
    private let triceps = "Extension Triceps Poulie Haute"

    private func makeImporter(workouts: (any WorkoutRepository)? = nil) -> HevyImporter {
        let now = Date.t0
        let repository = workouts ?? self.workouts
        let service = RecordsService(workouts: repository, records: records, userExercises: userExercises, library: .bundled,
                                     now: { now })
        return HevyImporter(workouts: repository, userExercises: userExercises, records: service, mappings: mappings,
                            library: .bundled, calendar: TestClock.calendar, now: { now })
    }

    private func proposed(_ preview: HevyImportPreview) -> [String: HevyMappingChoice] {
        Dictionary(uniqueKeysWithValues: preview.names.map { ($0.name, $0.choice) })
    }

    private func allSessions() async throws -> [WorkoutSession] {
        try await workouts.sessions(from: .distantPast, to: .distantFuture)
    }

    @Test func importCreatesSessionsCustomExercisesAndRecords() async throws {
        let importer = makeImporter()
        let preview = try await importer.preview(data)
        var choices = proposed(preview)
        choices[triceps] = .create(HevyNameGuesser.draft(for: triceps))
        let result = try await importer.run(preview, choices: choices, progress: { _ in })
        #expect(result.importedSessions == 2)
        #expect(result.createdExercises == 1)
        let created = try await userExercises.all(includeArchived: false)
        #expect(created.map(\.name) == [triceps])
        let exerciseID = try #require(created.first?.id)
        #expect(mappings.load()[triceps] == .user(id: exerciseID))
        #expect(mappings.load()["Tapis de Course"] == .ignore)
        #expect(try await records.records(for: nil).isEmpty == false)
        #expect(result.records == (try await records.records(for: nil).count))
        let pull = try #require(try await allSessions().first { $0.title == "Pull" })
        #expect(pull.sets.map(\.exercise) == [.user(id: exerciseID), .content(id: "wrist-curl-cable")])
        #expect(pull.sets.first?.exerciseName == triceps)
    }

    @Test func progressClimbsToOne() async throws {
        let importer = makeImporter()
        let preview = try await importer.preview(data)
        let steps = Steps()
        _ = try await importer.run(preview, choices: proposed(preview), progress: { steps.append($0) })
        #expect(steps.values == [0.5, 1])
    }

    @Test func importingTheSameExportTwiceAddsNothing() async throws {
        let importer = makeImporter()
        let first = try await importer.preview(data)
        let defaults = proposed(first)
        _ = try await importer.run(first, choices: defaults, progress: { _ in })
        let recordsAfterFirstImport = try await records.records(for: nil).count

        let again = try await importer.preview(data)
        #expect(again.newWorkouts.isEmpty && again.duplicateCount == 2)
        let result = try await importer.run(again, choices: defaults, progress: { _ in })
        #expect(result.importedSessions == 0)
        #expect(try await allSessions().count == 2)
        #expect(try await records.records(for: nil).count == recordsAfterFirstImport)
    }

    @Test func interruptedImportCompletesWithoutDuplicates() async throws {
        let failing = CountingWorkoutRepository(inner: workouts, failingAtSave: 2)
        let interrupted = makeImporter(workouts: failing)
        let stale = try await interrupted.preview(data)
        var choices = proposed(stale)
        choices[triceps] = .create(HevyNameGuesser.draft(for: triceps))
        await #expect(throws: CountingWorkoutRepository.Failure.self) {
            _ = try await interrupted.run(stale, choices: choices, progress: { _ in })
        }
        #expect(try await allSessions().count == 1)

        let importer = makeImporter()
        let resumed = try await importer.preview(data)
        #expect(resumed.newWorkouts.map(\.title) == ["Pull"] && resumed.duplicateCount == 1)
        let createdID = try #require(try await userExercises.all(includeArchived: false).first?.id)
        #expect(resumed.names.first { $0.name == triceps }?.choice == .user(id: createdID))
        let result = try await importer.run(resumed, choices: proposed(resumed), progress: { _ in })
        #expect(result.importedSessions == 1 && result.createdExercises == 0)
        #expect(try await allSessions().count == 2)
        #expect(try await userExercises.all(includeArchived: true).count == 1)
    }

    @Test func runningAStalePreviewSkipsSessionsAlreadySaved() async throws {
        let importer = makeImporter()
        let preview = try await importer.preview(data)
        _ = try await importer.run(preview, choices: proposed(preview), progress: { _ in })
        let result = try await importer.run(preview, choices: proposed(preview), progress: { _ in })
        #expect(result.importedSessions == 0)
        #expect(try await allSessions().count == 2)
    }

    private func tricepsReferences() async throws -> Set<ExerciseReference> {
        Set(try await allSessions().flatMap(\.sets).filter { $0.exerciseName == triceps }.map(\.exercise))
    }

    @Test func runningTheSamePreviewTwiceReusesTheCreatedExercise() async throws {
        let importer = makeImporter()
        let preview = try await importer.preview(data)
        var choices = proposed(preview)
        choices[triceps] = .create(HevyNameGuesser.draft(for: triceps))
        _ = try await importer.run(preview, choices: choices, progress: { _ in })
        try await workouts.delete(id: try #require(try await allSessions().first { $0.title == "Pull" }?.id))

        let again = try await importer.run(preview, choices: choices, progress: { _ in })
        #expect(again.createdExercises == 0 && again.importedSessions == 1)
        let created = try await userExercises.all(includeArchived: true)
        #expect(created.count == 1)
        #expect(try await tricepsReferences() == [.user(id: try #require(created.first?.id))])
    }

    @Test func retryingAFailedRunReusesTheCreatedExercise() async throws {
        let failing = CountingWorkoutRepository(inner: workouts, failingAtSave: 2)
        let interrupted = makeImporter(workouts: failing)
        let preview = try await interrupted.preview(data)
        var choices = proposed(preview)
        choices[triceps] = .create(HevyNameGuesser.draft(for: triceps))
        // « Push » est enregistrée, « Pull » (qui porte l'exercice créé) échoue.
        await #expect(throws: CountingWorkoutRepository.Failure.self) {
            _ = try await interrupted.run(preview, choices: choices, progress: { _ in })
        }

        let retried = try await makeImporter().run(preview, choices: choices, progress: { _ in })
        #expect(retried.createdExercises == 0 && retried.importedSessions == 1)
        let created = try await userExercises.all(includeArchived: true)
        #expect(created.count == 1)
        #expect(mappings.load()[triceps] == .user(id: try #require(created.first?.id)))
        #expect(try await tricepsReferences() == [.user(id: try #require(created.first?.id))])
    }

    @Test func aCreationMatchingAnExistingExerciseByNameReusesIt() async throws {
        var existing = HevyNameGuesser.draft(for: triceps).userExercise(id: UUID(), now: .t0)
        existing.name = "extension triceps poulie haute"
        try await userExercises.save(existing)
        let importer = makeImporter()
        let preview = try await importer.preview(data)
        var choices = proposed(preview)
        choices[triceps] = .create(HevyNameGuesser.draft(for: triceps))

        let result = try await importer.run(preview, choices: choices, progress: { _ in })
        #expect(result.createdExercises == 0)
        #expect(try await userExercises.all(includeArchived: true).map(\.id) == [existing.id])
        #expect(mappings.load()[triceps] == .user(id: existing.id))
    }

    @Test func removingImportedSessionsRecomputesRecords() async throws {
        let bench = ExerciseReference.content(id: "bench-press-barbell")
        let set = WorkoutSet(order: 0, exercise: bench, exerciseName: "Développé couché à la barre", setType: .working,
                             actualWeightKg: 80, actualReps: 5)
        let pulse = WorkoutSession(startedAt: TestClock.date("2026-11-01T18:00"), kind: .strength, source: .pulse,
                                   status: .completed, title: "Push", sets: [set], createdAt: .t0, updatedAt: .t0)
        try await workouts.save(pulse)
        let importer = makeImporter()
        let preview = try await importer.preview(data)
        _ = try await importer.run(preview, choices: proposed(preview), progress: { _ in })
        // Le développé couché de la séance Pulse bat celui du 26 octobre.
        #expect(try await workouts.session(id: pulse.id)?.sets.first?.isPersonalRecord == true)

        #expect(try await importer.removeImportedSessions() == 2)
        #expect(try await allSessions().map(\.id) == [pulse.id])
        let remaining = try await records.records(for: nil)
        #expect(!remaining.isEmpty && remaining.allSatisfy { $0.sessionID == pulse.id })
        #expect(try await workouts.session(id: pulse.id)?.sets.first?.isPersonalRecord == false)
    }

    @Test func previewOffersTheRememberedChoices() async throws {
        mappings.save(["Écarté (Machine)": .ignore])
        let preview = try await makeImporter().preview(data)
        #expect(preview.names.first { $0.name == "Écarté (Machine)" }?.choice == .ignore)
    }
}

/// Les valeurs de progression reçues, dans l'ordre.
private final class Steps: Sendable {
    private let stored = Mutex<[Double]>([])

    var values: [Double] { stored.withLock { $0 } }

    func append(_ value: Double) {
        stored.withLock { $0.append(value) }
    }
}

/// En série : les tests UserDefaults partagent une suite et la vident.
@Suite(.serialized)
struct HevyMappingStoreTests {
    private let suite = "fr.seonay.pulse.tests.hevy-mappings"

    private func clearSuite() {
        UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
    }

    @Test func userDefaultsStoreRoundTripsUnderThePulseKey() throws {
        clearSuite()
        defer { clearSuite() }
        let store = UserDefaultsHevyMappingStore(suiteName: suite)
        #expect(store.load().isEmpty)
        let choices: [String: HevyMappingChoice] = [
            "Bench": .content(id: "bench-press-barbell"), "Shrug": .user(id: ExerciseDirectoryTests.shrug.id), "Tapis": .ignore,
            "Nouveau": .create(HevyNameGuesser.draft(for: "Curl Poulie"))
        ]
        store.save(choices)
        #expect(UserDefaultsHevyMappingStore(suiteName: suite).load() == choices)
        let raw = try #require(UserDefaults(suiteName: suite)?.data(forKey: "pulse.hevyMappings"))
        #expect(try JSONDecoder().decode([String: HevyMappingChoice].self, from: raw) == choices)
    }

    @Test func unreadableMappingsLoadAsEmpty() {
        clearSuite()
        defer { clearSuite() }
        UserDefaults(suiteName: suite)?.set(Data("pas du json".utf8), forKey: "pulse.hevyMappings")
        #expect(UserDefaultsHevyMappingStore(suiteName: suite).load().isEmpty)
    }
}
