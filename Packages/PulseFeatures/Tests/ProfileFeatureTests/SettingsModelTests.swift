import Foundation
@testable import ProfileFeature
import PulseDomain
import PulseServices
import Testing

@MainActor
struct SettingsModelTests {
    let profiles = InMemoryProfileRepository()
    let cache = InMemoryHealthSampleCache()

    /// L'environnement de l'écran ; `refreshHealth` et `notificationsDenied` au choix du test.
    private func environment(notificationsDenied: Bool = false,
                             refreshHealth: @escaping @Sendable () async -> Void = {}) -> ProfileEnvironment {
        let calendar = ProfileTestClock.calendar
        let clock: @Sendable () -> Date = { ProfileTestClock.now }
        let service = ProfileService(profiles: profiles, programs: InMemoryProgramRepository(), workouts: InMemoryWorkoutRepository(),
                                     recoveries: InMemoryRecoveryRepository(calendar: calendar),
                                     records: InMemoryPersonalRecordRepository(), userExercises: InMemoryUserExerciseRepository(),
                                     library: .bundled, calendar: calendar, now: clock)
        return ProfileEnvironment(
            profile: service, body: BodyService(measurements: InMemoryBodyMeasurementRepository(), profiles: profiles,
                                                calendar: calendar, now: clock),
            settings: SettingsService(profiles: profiles, now: clock) { _, _ in }, healthCache: cache,
            inspector: SilentInspector(), exporter: SilentExporter(), eraser: SilentEraser(),
            notificationsDenied: { notificationsDenied }, refreshHealth: refreshHealth, appVersion: "1.0.2 (14)",
            privacyPolicyURL: nil, calendar: calendar, now: clock)
    }

    private func storeProfile() async throws -> UserProfile {
        let created = ProfileTestClock.date(2026, 11, 2, hour: 9)
        let profile = UserProfile(firstName: "Mathéo", onboardingCompletedAt: created, createdAt: created, updatedAt: created)
        try await profiles.save(profile)
        return profile
    }

    private func sample(_ kind: HealthSampleKind, start: Date, end: Date, fetchedAt: Date) -> CachedHealthSample {
        CachedHealthSample(kind: kind, start: start, end: end, value: 1, fetchedAt: fetchedAt)
    }

    @Test func loadReadsProfileHealthAndNotifications() async throws {
        let stored = try await storeProfile()
        let fetched = ProfileTestClock.date(2026, 11, 20, hour: 7)
        let weighed = ProfileTestClock.date(2026, 11, 19, hour: 7)
        let bedtime = ProfileTestClock.date(2026, 11, 19, hour: 23)
        let wakeUp = ProfileTestClock.date(2026, 11, 20, hour: 7)
        try await cache.insert([sample(.bodyMass, start: weighed, end: weighed, fetchedAt: fetched),
                                sample(.sleep, start: bedtime, end: wakeUp, fetchedAt: fetched)])
        let model = SettingsModel(environment: environment(notificationsDenied: true)) { _ in }

        await model.load()

        #expect(model.profile == stored)
        #expect(model.notificationsDenied)
        #expect(model.errorMessage == nil)
        let health = try #require(model.health)
        #expect(health.lastRead == fetched)
        #expect(health.kinds.map(\.kind) == HealthSampleKind.allCases)
        #expect(health.kinds.first { $0.kind == .bodyMass }?.latest == weighed)
        #expect(health.kinds.first { $0.kind == .sleep }?.latest == wakeUp, "Une nuit compte au jour du réveil")
        #expect(health.kinds.first { $0.kind == .run }?.latest == nil)
    }

    @Test func updateSavesThroughTheServiceAndReportsTheProfile() async throws {
        _ = try await storeProfile()
        let saved = SavedProfiles()
        let model = SettingsModel(environment: environment()) { saved.profiles.append($0) }
        await model.load()

        await model.update { $0.theme = .amethyst }

        #expect(try await profiles.load()?.theme == .amethyst)
        #expect(model.profile?.theme == .amethyst)
        #expect(model.profile?.updatedAt == ProfileTestClock.now)
        #expect(saved.profiles.map(\.theme) == [.amethyst], "L'app reçoit le nouveau thème")
        #expect(model.errorMessage == nil)

        await model.update { $0.theme = .amethyst }
        #expect(saved.profiles.count == 1, "Un réglage inchangé ne prévient pas l'app")
    }

    @Test func invalidUpdateShowsMessageAndReloads() async throws {
        let stored = try await storeProfile()
        let saved = SavedProfiles()
        let model = SettingsModel(environment: environment()) { saved.profiles.append($0) }
        await model.load()

        await model.update { $0.defaultRestSeconds = 75 }

        #expect(model.errorMessage == "Choisis un repos de 60, 90, 120 ou 180 s.")
        #expect(model.profile == stored, "Le profil stocké est relu, inchangé")
        #expect(try await profiles.load() == stored)
        #expect(saved.profiles.isEmpty)

        await model.update { $0.defaultRestSeconds = 120 }
        #expect(model.errorMessage == nil, "Un réglage valide efface le message")
        #expect(model.profile?.defaultRestSeconds == 120)
    }

    @Test func otherErrorsHaveTheirMessage() async throws {
        let model = SettingsModel(environment: environment()) { _ in }
        await model.update { $0.theme = .amethyst }
        #expect(model.errorMessage == "Ton profil est introuvable.")

        _ = try await storeProfile()
        let cases: [(String, @Sendable (inout UserProfile) -> Void)] = [
            ("Entre une taille entre 100 et 250 cm.", { $0.heightCm = 90 }),
            ("L'incrément doit être positif.", { $0.upperIncrementKg = 0 }),
            ("Choisis une heure entre 6 h et 12 h.", { $0.morningScoreDeadlineMinutes = 780 }),
            ("Garde au moins un disque et une barre de plus de 0 kg.", { $0.availablePlatesKg = [] })
        ]
        for (message, change) in cases {
            await model.update(change)
            #expect(model.errorMessage == message)
        }
    }

    @Test func heightTextIsParsedBeforeSaving() async throws {
        _ = try await storeProfile()
        let model = SettingsModel(environment: environment()) { _ in }
        await model.load()

        await model.commitHeight(" 178,5 ")
        #expect(model.profile?.heightCm == 178.5)

        await model.commitHeight("abc")
        #expect(model.errorMessage == "Entre une taille entre 100 et 250 cm.")
        #expect(model.profile?.heightCm == 178.5)

        await model.commitHeight("")
        #expect(model.profile?.heightCm == nil, "Un champ vidé efface la taille")
        #expect(model.errorMessage == nil)
    }

    @Test func refreshHealthCallsThePassThenRereadsStatus() async throws {
        _ = try await storeProfile()
        let ran = ProfileTestClock.date(2026, 11, 20, hour: 11)
        let run = sample(.run, start: ProfileTestClock.date(2026, 11, 20, hour: 8),
                         end: ProfileTestClock.date(2026, 11, 20, hour: 9), fetchedAt: ran)
        let cache = cache
        let model = SettingsModel(environment: environment(refreshHealth: { try? await cache.insert([run]) })) { _ in }
        await model.load()
        #expect(model.health?.lastRead == nil)

        await model.refreshHealth()

        #expect(model.health?.lastRead == ran)
        #expect(model.health?.kinds.first { $0.kind == .run }?.latest == run.start)
        #expect(!model.isRefreshingHealth)
    }
}

/// Les profils reçus par `onProfileSaved`.
@MainActor
final class SavedProfiles {
    var profiles: [UserProfile] = []
}

struct SettingsTextTests {
    @Test func healthKindsAndSexHaveFrenchNames() {
        #expect(HealthSampleKind.allCases.map(ProfileText.healthKind)
            == ["VFC", "FC au repos", "Sommeil", "Courses", "Vélo", "Poids", "Masse grasse"])
        #expect(Sex.allCases.map(ProfileText.sex) == ["Femme", "Homme", "Non précisé"])
    }

    @Test func lastReadShowsDayAndTime() {
        let read = ProfileTestClock.date(2026, 11, 20, hour: 7).addingTimeInterval(30 * 60)
        #expect(ProfileText.dateTime(read, calendar: ProfileTestClock.calendar) == "20 nov. 2026 à 07:30")
    }

    @Test func deadlinesRunFromSixToNoonByHalfHour() {
        #expect(NotificationSettingsSection.deadlines.first == 360 && NotificationSettingsSection.deadlines.last == 720)
        #expect(NotificationSettingsSection.deadlines.count == 13)
    }
}
