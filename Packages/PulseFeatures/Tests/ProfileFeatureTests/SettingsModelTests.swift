import Foundation
@testable import ProfileFeature
import PulseDomain
import PulseServices
import Testing

@MainActor
struct SettingsModelTests {
    let profiles = InMemoryProfileRepository()
    let cache = InMemoryHealthSampleCache()

    /// L'environnement de l'écran ; `refreshHealth`, l'autorisation des notifications, la réponse d'iOS et la demande d'accès à
    /// Apple Santé au choix du test.
    func environment(notifications: NotificationAuthorizationStatus = .authorized,
                     permission: StubNotificationAuthorizer = StubNotificationAuthorizer(granted: true),
                     refreshHealth: @escaping @Sendable () async -> Void = {},
                     runPreferences: any RunPreferencesStore = InMemoryRunPreferencesStore(),
                     sleepPlan: @escaping @Sendable () async -> SleepPlan? = { nil },
                     healthAccess: HealthAccess? = nil) -> ProfileEnvironment {
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
            notificationStatus: { notifications }, requestNotificationAuthorization: { await permission.requestAuthorization() },
            refreshHealth: refreshHealth, appVersion: "1.0.2 (14)",
            privacyPolicyURL: nil, calendar: calendar, now: clock, runPreferences: runPreferences, sleepPlan: sleepPlan,
            healthAccess: healthAccess)
    }

    func storeProfile() async throws -> UserProfile {
        let created = ProfileTestClock.date(2026, 11, 2, hour: 9)
        let profile = UserProfile(firstName: "Mathéo", onboardingCompletedAt: created, createdAt: created, updatedAt: created)
        try await profiles.save(profile)
        return profile
    }

    func sample(_ kind: HealthSampleKind, start: Date, end: Date, fetchedAt: Date) -> CachedHealthSample {
        CachedHealthSample(kind: kind, start: start, end: end, value: 1, fetchedAt: fetchedAt)
    }

    @Test func announcementsToggleWritesThePreference() async throws {
        _ = try await storeProfile()
        let store = InMemoryRunPreferencesStore(announcesKilometres: false)
        let model = SettingsModel(environment: environment(runPreferences: store)) { _ in }
        #expect(model.announcesKilometres)

        await model.load()
        #expect(!model.announcesKilometres)

        model.setAnnouncesKilometres(true)
        #expect(model.announcesKilometres && store.announcesKilometres)
        model.setAnnouncesKilometres(false)
        #expect(!model.announcesKilometres && !store.announcesKilometres)
    }

    @Test func loadReadsProfileHealthAndNotifications() async throws {
        let stored = try await storeProfile()
        let fetched = ProfileTestClock.date(2026, 11, 20, hour: 7)
        let weighed = ProfileTestClock.date(2026, 11, 19, hour: 7)
        let bedtime = ProfileTestClock.date(2026, 11, 19, hour: 23)
        let wakeUp = ProfileTestClock.date(2026, 11, 20, hour: 7)
        try await cache.insert([sample(.bodyMass, start: weighed, end: weighed, fetchedAt: fetched),
                                sample(.sleep, start: bedtime, end: wakeUp, fetchedAt: fetched)])
        let model = SettingsModel(environment: environment(notifications: .denied)) { _ in }

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

        #expect(model.errorMessage == "Choisis un repos de 60, 90, 120 ou 180 secondes.")
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
            ("Entre une taille entre 100 et 250 centimètres.", { $0.heightCm = 90 }),
            ("L'incrément doit être positif.", { $0.upperIncrementKg = 0 }),
            ("Choisis une heure entre 6 heures et 12 heures.", { $0.morningScoreDeadlineMinutes = 780 }),
            ("Garde au moins un disque et une barre de plus de 0 kilo.", { $0.availablePlatesKg = [] })
        ]
        for (message, change) in cases {
            await model.update(change)
            #expect(model.errorMessage == message)
        }
    }

    @Test func everyRefusedSettingCountsAsAFailure() async throws {
        _ = try await storeProfile()
        let model = SettingsModel(environment: environment()) { _ in }
        await model.load()
        #expect(model.failureCount == 0)

        await model.update { $0.heightCm = 90 }
        await model.update { $0.heightCm = 90 }
        #expect(model.errorMessage == "Entre une taille entre 100 et 250 centimètres.")
        #expect(model.failureCount == 2, "La même erreur deux fois : deux annonces")

        await model.commitHeight("abc")
        #expect(model.failureCount == 3)

        await model.update { $0.heightCm = 180 }
        #expect(model.errorMessage == nil && model.failureCount == 3)
    }

    @Test func quickPlateTapsBothLand() async throws {
        _ = try await storeProfile()
        let model = SettingsModel(environment: environment()) { _ in }
        await model.load()

        let first = Task { await model.update { $0.setPlate(25, available: false) } }
        let second = Task { await model.update { $0.setPlate(0.5, available: true) } }
        await first.value
        await second.value

        #expect(try await profiles.load()?.availablePlatesKg == [20, 15, 10, 5, 2.5, 1.25, 0.5])
        #expect(model.profile?.availablePlatesKg == [20, 15, 10, 5, 2.5, 1.25, 0.5])
    }

    @Test func heightTextIsParsedBeforeSaving() async throws {
        _ = try await storeProfile()
        let model = SettingsModel(environment: environment()) { _ in }
        await model.load()

        await model.commitHeight(" 178,5 ")
        #expect(model.profile?.heightCm == 178.5)

        await model.commitHeight("abc")
        #expect(model.errorMessage == "Entre une taille entre 100 et 250 centimètres.")
        #expect(model.profile?.heightCm == 178.5)

        await model.commitHeight("")
        #expect(model.profile?.heightCm == nil, "Un champ vidé efface la taille")
        #expect(model.errorMessage == nil)
    }

    /// Un profil dont les trois notifications sont coupées.
    private func storeProfileWithNotificationsOff() async throws {
        var profile = try await storeProfile()
        profile.morningScoreNotification = false
        profile.supplementRemindersEnabled = false
        profile.restTimerNotificationEnabled = false
        try await profiles.save(profile)
    }

    @Test func turningANotificationOnAsksIOSAndKeepsItWhenGranted() async throws {
        try await storeProfileWithNotificationsOff()
        let permission = StubNotificationAuthorizer(granted: true)
        let saved = SavedProfiles()
        let model = SettingsModel(environment: environment(notifications: .notDetermined, permission: permission)) {
            saved.profiles.append($0)
        }
        await model.load()
        #expect(!model.notificationsDenied, "Pas encore demandée : pas de lien vers les réglages d'iOS")

        await model.setNotification(true) { $0.morningScoreNotification = $1 }

        #expect(await permission.requestCount == 1)
        #expect(try await profiles.load()?.morningScoreNotification == true)
        #expect(model.profile?.morningScoreNotification == true)
        #expect(!model.notificationsDenied)
        #expect(saved.profiles.map(\.morningScoreNotification) == [true])
    }

    @Test func refusedPermissionTurnsTheNotificationBackOff() async throws {
        try await storeProfileWithNotificationsOff()
        let permission = StubNotificationAuthorizer(granted: false)
        let model = SettingsModel(environment: environment(notifications: .notDetermined, permission: permission)) { _ in }
        await model.load()

        await model.setNotification(true) { $0.supplementRemindersEnabled = $1 }

        #expect(await permission.requestCount == 1)
        #expect(try await profiles.load()?.supplementRemindersEnabled == false)
        #expect(model.profile?.supplementRemindersEnabled == false)
        #expect(model.notificationsDenied)
    }

    @Test func deniedNotificationsRevertWithoutAskingAgain() async throws {
        try await storeProfileWithNotificationsOff()
        let permission = StubNotificationAuthorizer(granted: true)
        let model = SettingsModel(environment: environment(notifications: .denied, permission: permission)) { _ in }
        await model.load()

        await model.setNotification(true) { $0.restTimerNotificationEnabled = $1 }

        #expect(await permission.requestCount == 0, "Refusées dans iOS : seule l'app Réglages peut les rendre")
        #expect(try await profiles.load()?.restTimerNotificationEnabled == false)
        #expect(model.notificationsDenied)
    }

    @Test func authorizedOrTurningOffNeverAsks() async throws {
        try await storeProfileWithNotificationsOff()
        let permission = StubNotificationAuthorizer(granted: false)
        let model = SettingsModel(environment: environment(notifications: .authorized, permission: permission)) { _ in }
        await model.load()

        await model.setNotification(true) { $0.morningScoreNotification = $1 }
        await model.setNotification(false) { $0.morningScoreNotification = $1 }

        #expect(await permission.requestCount == 0)
        #expect(try await profiles.load()?.morningScoreNotification == false)
        #expect(!model.notificationsDenied)
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

// MARK: - Sommeil

extension SettingsModelTests {
    /// Le plan relu dans le dépôt des profils, avec des réveils à `wake` (minutes après minuit) du lundi 16 au vendredi
    /// 20 novembre (aucun : pas d'heure habituelle).
    private func sleepPlan(wake: Int? = nil) -> @Sendable () async -> SleepPlan? {
        let profiles = profiles
        let wokeUp = wake.map { wake in
            (16...20).map { ProfileTestClock.date(2026, 11, $0).addingTimeInterval(TimeInterval(wake * 60)) }
        } ?? []
        return { SleepPlan(profile: try? await profiles.load(), wokeUp: wokeUp, calendar: ProfileTestClock.calendar) }
    }

    @Test func sleepPlanIsReloadedAfterAChange() async throws {
        _ = try await storeProfile()
        let model = SettingsModel(environment: environment(sleepPlan: sleepPlan())) { _ in }
        await model.load()
        #expect(model.sleepPlan?.goalMinutes == SleepGoal.defaultMinutes)

        await model.update { $0.sleepGoalMinutes = 450 }

        #expect(model.sleepPlan?.goalMinutes == 450, "Le footer suit le nouvel objectif")
    }

    @Test func followingNightsWritesNothingInTheProfile() async throws {
        var stored = try await storeProfile()
        stored.weekdayWakeMinutes = 450
        try await profiles.save(stored)
        let model = SettingsModel(environment: environment(sleepPlan: sleepPlan(wake: 420))) { _ in }
        await model.load()
        #expect(model.sleepPlan?.habitualWeekdayWake == 420)

        await model.chooseWake(false, weekend: false)

        let saved = try #require(try await profiles.load())
        #expect(saved.weekdayWakeMinutes == nil, "L'heure mesurée n'est jamais écrite")
        #expect(model.sleepPlan?.wakeMinutes(weekend: false) == 420)
    }

    @Test func choosingATimeStartsFromTheFixedDefaultNeverTheHabitualWake() async throws {
        _ = try await storeProfile()
        let model = SettingsModel(environment: environment(sleepPlan: sleepPlan(wake: 430))) { _ in }
        await model.load()
        #expect(model.sleepPlan?.habitualWeekdayWake == 430 && model.sleepPlan?.habitualWeekendWake == 430)

        await model.chooseWake(true, weekend: false)
        await model.chooseWake(true, weekend: true)
        let saved = try #require(try await profiles.load())
        #expect(saved.weekdayWakeMinutes == 420, "07:00, jamais l'heure tirée d'Apple Santé")
        #expect(saved.weekendWakeMinutes == 540, "09:00, jamais l'heure tirée d'Apple Santé")

        await model.setWake(553, weekend: true)
        #expect(try await profiles.load()?.weekendWakeMinutes == 555, "Arrondi à 5 minutes")
        await model.chooseWake(true, weekend: true)
        #expect(try await profiles.load()?.weekendWakeMinutes == 555, "Déjà choisie : l'heure reste")
    }

    @Test func deniedNotificationsTurnTheBedtimeReminderBackOff() async throws {
        _ = try await storeProfile()
        let permission = StubNotificationAuthorizer(granted: false)
        let model = SettingsModel(environment: environment(notifications: .notDetermined, permission: permission)) { _ in }
        await model.load()

        await model.setNotification(true) { $0.bedtimeReminderEnabled = $1 }

        #expect(try await profiles.load()?.bedtimeReminderEnabled == false)
        #expect(model.profile?.bedtimeReminderEnabled == false)
        #expect(model.notificationsDenied)
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

    @Test func plateChoicesMatchThePlateCalculator() {
        #expect(SessionSettingsSection.plateChoices == [25, 20, 15, 10, 5, 2.5, 2, 1.25, 1, 0.5])
    }

    @Test func deadlinesRunFromSixToNoonByHalfHour() {
        #expect(NotificationSettingsSection.deadlines.first == 360 && NotificationSettingsSection.deadlines.last == 720)
        #expect(NotificationSettingsSection.deadlines.count == 13)
    }
}
