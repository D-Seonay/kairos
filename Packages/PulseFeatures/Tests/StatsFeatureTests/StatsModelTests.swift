// swiftlint:disable force_unwrapping
import Foundation
import PulseContent
import PulseDomain
import PulseServices
@testable import StatsFeature
import Testing
import TrainFeature

/// Un dépôt de séances en mémoire qui compte les lectures et qui échoue sur demande.
actor ScriptedWorkouts: WorkoutRepository {
    struct Failure: Error {}

    private let base = InMemoryWorkoutRepository()
    private(set) var reads = 0
    private var failing = false

    func setFailing(_ failing: Bool) { self.failing = failing }

    func sessions(from: Date, to: Date) async throws -> [WorkoutSession] {
        reads += 1
        if failing { throw Failure() }
        return try await base.sessions(from: from, to: to)
    }

    func session(id: UUID) async throws -> WorkoutSession? { try await base.session(id: id) }
    func save(_ session: WorkoutSession) async throws { try await base.save(session) }
    func delete(id: UUID) async throws { try await base.delete(id: id) }
    func lastSets(for exercise: ExerciseReference, startedBefore date: Date) async throws -> [WorkoutSet] {
        try await base.lastSets(for: exercise, startedBefore: date)
    }
}

@MainActor
struct StatsModelTests {
    let workouts = ScriptedWorkouts()
    let environment: StatsEnvironment

    init() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
        calendar.locale = Locale(identifier: "fr_FR")
        let now = calendar.date(from: DateComponents(year: 2026, month: 11, day: 20, hour: 12))!
        let clock: @Sendable () -> Date = { now }
        let library = ContentLibrary.bundled
        let profiles = InMemoryProfileRepository()
        let programs = InMemoryProgramRepository()
        let recoveries = InMemoryRecoveryRepository(calendar: calendar)
        let userExercises = InMemoryUserExerciseRepository()
        let personalRecords = InMemoryPersonalRecordRepository()
        let settings = InMemoryExerciseSettingsRepository()
        let records = RecordsService(workouts: workouts, records: personalRecords, userExercises: userExercises, library: library,
                                     now: clock)
        let importer = HevyImporter(workouts: workouts, userExercises: userExercises, records: records,
                                    mappings: InMemoryHevyMappingStore(), library: library, calendar: calendar, now: clock)
        let activeSession = ActiveSessionService(
            store: InMemoryActiveSessionStore(), workouts: workouts, profiles: profiles, settings: settings,
            userExercises: userExercises, records: records, library: library, restNotifier: StubRestTimerNotifier(),
            activity: StubSessionActivityController(), calendar: calendar, now: clock)
        let train = TrainEnvironment(
            profiles: profiles, programs: programs, recovery: recoveries, workouts: workouts, userExercises: userExercises,
            exerciseSettings: settings, personalRecords: personalRecords, records: records, importer: importer, library: library,
            activeSession: activeSession, calendar: calendar, now: clock)
        let service = StatsService(profiles: profiles, programs: programs, workouts: workouts, recoveries: recoveries,
                                   records: personalRecords, userExercises: userExercises, library: library, calendar: calendar,
                                   now: clock)
        environment = StatsEnvironment(service: service, train: train, calendar: calendar, now: clock)
    }

    @Test func loadFillsSnapshot() async {
        let model = StatsModel(environment: environment)
        #expect(model.snapshot == nil && !model.hasLoaded)
        #expect(model.view == .load && model.period == .month)

        await model.load()

        #expect(model.snapshot?.period == .month)
        #expect(model.errorMessage == nil && model.hasLoaded)
        #expect(await workouts.reads == 1)
    }

    @Test func changingPeriodReloads() async {
        let model = StatsModel(environment: environment)
        await model.load()
        #expect(await workouts.reads == 1)

        model.period = .year
        await model.reloadTask?.value

        #expect(model.snapshot?.period == .year)
        #expect(await workouts.reads == 2)
        model.period = .year
        #expect(await workouts.reads == 2, "Rechoisir la même période ne relit rien")
    }

    @Test func failureKeepsLastSnapshotAndShowsError() async {
        let model = StatsModel(environment: environment)
        await model.load()
        await workouts.setFailing(true)

        model.period = .week
        await model.reloadTask?.value

        #expect(model.snapshot?.period == .month, "L'écran garde son dernier état")
        #expect(model.errorMessage == "Pulse n'a pas pu lire tes statistiques.")

        await workouts.setFailing(false)
        await model.load()
        #expect(model.snapshot?.period == .week && model.errorMessage == nil)
    }

    @Test func viewTitlesAreFrench() {
        #expect(StatsView.allCases.map(\.title) == ["Charge", "Biométrie", "Muscles", "Assiduité", "Records"])
    }
}

struct StatsTextTests {
    @Test func formatsInFrench() {
        #expect(StatsText.change(StatsComparison(value: 106, previous: 100)) == "+6 %")
        #expect(StatsText.change(StatsComparison(value: 96, previous: 100)) == "\u{2212}4 %")
        #expect(StatsText.change(StatsComparison(value: 5, previous: nil)) == nil)
        #expect(StatsText.change(StatsComparison(value: 5, previous: 0)) == nil)
        #expect(StatsText.change(nil) == nil)
        #expect(StatsText.duration(minutes: 432) == "7 h 12")
        #expect(StatsText.duration(minutes: 45.4) == "45 min")
        #expect(StatsText.raceTime(seconds: 1_471) == "24:31")
        #expect(StatsText.raceTime(seconds: 6_307) == "1:45:07")
        #expect(StatsText.pace(secondsPerKm: 294) == "4:54 /km")
        #expect(StatsText.number(91_200) == "91\u{202F}200")
        #expect(StatsText.number(2_140.4) == "2\u{202F}140")
        #expect(StatsText.number(850) == "850")
    }

    @Test func impossibleValuesShowADash() {
        #expect(StatsText.number(.nan) == "\u{2014}")
        #expect(StatsText.duration(minutes: -1) == "\u{2014}")
        #expect(StatsText.raceTime(seconds: .infinity) == "\u{2014}")
        #expect(StatsText.pace(secondsPerKm: .nan) == "\u{2014}")
    }
}
// swiftlint:enable force_unwrapping
