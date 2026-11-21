// swiftlint:disable force_unwrapping
import Foundation
@testable import ProfileFeature
import PulseContent
import PulseDomain
import PulseServices
import Testing

/// Un dépôt de séances en mémoire qui compte les lectures, échoue sur demande et peut suspendre la prochaine lecture.
actor ScriptedWorkouts: WorkoutRepository {
    struct Failure: Error {}

    private let base = InMemoryWorkoutRepository()
    private(set) var reads = 0
    private var failing = false
    private var gateArmed = false
    private var gate: CheckedContinuation<Void, Never>?

    func setFailing(_ failing: Bool) { self.failing = failing }

    /// La prochaine lecture attend `releaseGate()`.
    func armGate() { gateArmed = true }
    var isSuspended: Bool { gate != nil }
    func releaseGate() {
        gate?.resume()
        gate = nil
    }

    func sessions(from: Date, to: Date) async throws -> [WorkoutSession] {
        reads += 1
        if gateArmed {
            gateArmed = false
            await withCheckedContinuation { gate = $0 }
        }
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

/// Les données stockées ne servent pas à la page Profil : des doublures muettes.
struct SilentInspector: StoreInspector {
    func counts() async throws -> [StoreTable: Int] { [:] }
    func cloudAccountStatus() async -> CloudAccountStatus { .unknown }
}

struct SilentExporter: DataExporter {
    func exportJSON() async throws -> URL { URL(fileURLWithPath: "/dev/null") }
    func exportCSVArchive() async throws -> URL { URL(fileURLWithPath: "/dev/null") }
}

struct SilentEraser: DataEraser {
    func eraseEverything(options: EraseOptions) async throws {}
}

enum ProfileTestClock {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
        calendar.locale = Locale(identifier: "fr_FR")
        return calendar
    }()

    /// Vendredi 20 novembre 2026, midi.
    static let now = date(2026, 11, 20, hour: 12)

    static func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }
}

@MainActor
struct ProfileModelTests {
    let workouts = ScriptedWorkouts()
    let profiles = InMemoryProfileRepository()
    let measurements = InMemoryBodyMeasurementRepository()
    let environment: ProfileEnvironment

    init() {
        let calendar = ProfileTestClock.calendar
        let clock: @Sendable () -> Date = { ProfileTestClock.now }
        let service = ProfileService(profiles: profiles, programs: InMemoryProgramRepository(), workouts: workouts,
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

    /// Le profil de Mathéo, trois séances de musculation cette semaine et une pesée mercredi.
    private func seed() async throws {
        let onboarded = ProfileTestClock.date(2026, 11, 2, hour: 9)
        try await profiles.save(UserProfile(firstName: "Mathéo", onboardingCompletedAt: onboarded, createdAt: onboarded,
                                            updatedAt: onboarded))
        for day in [16, 17, 18] {
            let start = ProfileTestClock.date(2026, 11, day, hour: 18)
            try await workouts.save(WorkoutSession(startedAt: start, kind: .strength, source: .pulse, status: .completed,
                                                   title: "Séance", createdAt: start, updatedAt: start))
        }
        let weighed = ProfileTestClock.date(2026, 11, 18, hour: 7)
        try await measurements.save(BodyMeasurement(date: weighed, weightKg: 78.4, source: .manual, createdAt: weighed,
                                                    updatedAt: weighed))
    }

    private func model() -> ProfileModel {
        ProfileModel(environment: environment) { _ in }
    }

    @Test func loadFillsSummaryAndBody() async throws {
        try await seed()
        let model = model()
        #expect(model.summary == nil && model.body == nil && !model.hasLoaded)

        await model.load()

        #expect(model.summary?.firstName == "Mathéo")
        #expect(model.summary?.sessionsTotal == 3)
        #expect(model.summary?.firstSession == ProfileTestClock.date(2026, 11, 16, hour: 18))
        #expect(model.body?.trend.current == 78.4)
        #expect(model.body?.measurements.count == 1)
        #expect(model.errorMessage == nil && model.hasLoaded)
    }

    @Test func failureKeepsLastDataAndShowsError() async throws {
        try await seed()
        let model = model()
        await model.load()
        await workouts.setFailing(true)

        await model.load()

        #expect(model.summary?.sessionsTotal == 3, "L'écran garde son dernier état")
        #expect(model.body?.trend.current == 78.4)
        #expect(model.errorMessage == "Pulse n'a pas pu lire ton profil.")

        await workouts.setFailing(false)
        let start = ProfileTestClock.date(2026, 11, 19, hour: 18)
        try await workouts.save(WorkoutSession(startedAt: start, kind: .strength, source: .pulse, status: .completed,
                                               title: "Séance", createdAt: start, updatedAt: start))
        await model.load()
        #expect(model.summary?.sessionsTotal == 4 && model.errorMessage == nil)
    }

    @Test func loadDuringALoadIsIgnored() async throws {
        try await seed()
        let model = model()
        await workouts.armGate()
        let first = Task { await model.load() }
        // Borné : une régression qui ne suspend jamais la lecture doit échouer, pas bloquer la suite.
        var polls = 0
        while !(await workouts.isSuspended) {
            polls += 1
            guard polls < 10_000 else {
                Issue.record("La lecture ne s'est jamais suspendue")
                await workouts.releaseGate()
                await first.value
                return
            }
            await Task.yield()
        }

        await model.load()
        #expect(!model.hasLoaded, "Le second appel rend la main sans lire")
        await workouts.releaseGate()
        await first.value

        #expect(await workouts.reads == 1)
        #expect(model.summary?.sessionsTotal == 3 && model.hasLoaded)
    }
}

struct ProfileTextTests {
    let calendar = ProfileTestClock.calendar

    @Test func sessionsSinceTheFirstOne() {
        let first = ProfileTestClock.date(2026, 3, 14, hour: 18)
        #expect(ProfileText.sessionsSince(12, firstSession: first, calendar: calendar) == "12 séances · depuis mars 2026")
        #expect(ProfileText.sessionsSince(1, firstSession: first, calendar: calendar) == "1 séance · depuis mars 2026")
        #expect(ProfileText.sessionsSince(0, firstSession: nil, calendar: calendar) == "Aucune séance pour l'instant")
    }

    @Test func weightFormats() {
        #expect(ProfileText.weight(78.4) == "78,4 kg")
        #expect(ProfileText.weight(80) == "80 kg")
        #expect(ProfileText.weightChange(-0.8) == "\u{2212}0,8 kg en 30 j")
        #expect(ProfileText.weightChange(1.25) == "+1,3 kg en 30 j")
        #expect(ProfileText.weightChange(0.04) == "0 kg en 30 j")
        #expect(ProfileText.weightChange(-0.04) == "0 kg en 30 j")
        let fat = BodyFatReading(percent: 17.5, date: ProfileTestClock.date(2026, 11, 12, hour: 7))
        #expect(ProfileText.bodyFat(fat, calendar: calendar, today: ProfileTestClock.now) == "17,5 % · 12 nov.")
    }

    @Test func badgeTexts() {
        #expect(ProfileText.badgeTitle(.streak(weeks: 4)) == "4 semaines d'affilée")
        #expect(ProfileText.badgeTitle(.sessions(count: 10)) == "10 séances")
        #expect(ProfileText.badgeTitle(.firstFullMonth) == "Premier mois complet")
        #expect(ProfileText.badgeProgress(Badge(kind: .streak(weeks: 12), earnedAt: nil, current: 9, goal: 12))
            == "9 / 12 semaines")
        #expect(ProfileText.badgeProgress(Badge(kind: .sessions(count: 50), earnedAt: nil, current: 37, goal: 50))
            == "37 / 50 séances")
        #expect(ProfileText.badgeProgress(Badge(kind: .firstFullMonth, earnedAt: nil, current: 1, goal: 4))
            == "1 / 4 semaines")
        let earned = ProfileTestClock.date(2026, 11, 12, hour: 18)
        #expect(ProfileText.earnedDate(earned, calendar: calendar) == "12 nov. 2026")
    }

    @Test func impossibleValuesShowADash() {
        #expect(ProfileText.weight(.nan) == "\u{2014}")
        #expect(ProfileText.weightChange(.infinity) == "\u{2014}")
    }
}
// swiftlint:enable force_unwrapping
