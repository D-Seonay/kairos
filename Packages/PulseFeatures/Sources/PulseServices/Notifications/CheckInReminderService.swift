import Foundation
import PulseDomain
import Synchronization

/// Le réglage du rappel de check-in, gardé par appareil (hors du profil synchronisé, comme le rappel de photos de corps).
public protocol CheckInReminderStore: Sendable {
    var settings: CheckInReminderSettings { get }
    func save(_ settings: CheckInReminderSettings)
}

/// Réglage gardé dans `UserDefaults`, dans la suite que la suppression totale vide. Seul le nom de la suite est retenu :
/// `UserDefaults` n'est pas `Sendable`.
public final class UserDefaultsCheckInReminderStore: CheckInReminderStore {
    static let disabledKey = "pulse.checkInReminder.disabled"
    static let minutesKey = "pulse.checkInReminder.minutes"

    private let suiteName: String?

    public init(suiteName: String?) {
        self.suiteName = suiteName
    }

    private var defaults: UserDefaults {
        suiteName.flatMap(UserDefaults.init(suiteName:)) ?? .standard
    }

    public var settings: CheckInReminderSettings {
        CheckInReminderSettings(enabled: !defaults.bool(forKey: Self.disabledKey),
                                chosenMinutes: defaults.object(forKey: Self.minutesKey) as? Int)
    }

    public func save(_ settings: CheckInReminderSettings) {
        defaults.set(!settings.enabled, forKey: Self.disabledKey)
        if let minutes = settings.chosenMinutes {
            defaults.set(minutes, forKey: Self.minutesKey)
        } else {
            defaults.removeObject(forKey: Self.minutesKey)
        }
    }
}

/// Réglage en mémoire, pour les tests et les aperçus.
public final class InMemoryCheckInReminderStore: CheckInReminderStore {
    private let stored: Mutex<CheckInReminderSettings>

    public init(settings: CheckInReminderSettings = CheckInReminderSettings()) {
        stored = Mutex(settings)
    }

    public var settings: CheckInReminderSettings { stored.withLock { $0 } }

    public func save(_ settings: CheckInReminderSettings) {
        stored.withLock { $0 = settings }
    }
}

/// Le rappel quotidien de check-in pour qui n'a pas de montre (`CheckInReminderRule`) : lit le réglage, les dernières mesures de
/// montre du cache d'Apple Santé, le check-in et le score du jour et les réveils habituels, puis remet les rappels au
/// planificateur. Replanifié à chaque passage du jour (premier plan et arrière-plan) et après un check-in. Les recalculs passent
/// l'un après l'autre et chacun relit tout : la dernière demande l'emporte.
public struct CheckInReminderService: Sendable {
    /// Les jours de mesures de montre relus : au-delà, plus rien ne change.
    static let watchWindowDays = 30

    private let store: any CheckInReminderStore
    private let profiles: any ProfileRepository
    private let recovery: any RecoveryRepository
    private let cache: any HealthSampleCache
    private let bedtime: HabitualBedtimeReader
    private let scheduler: any CheckInReminderScheduling
    private let notifications: (any NotificationAuthorizing)?
    private let saveCheckIn: @Sendable (CheckInAnswers) async throws -> Void
    private let calendar: Calendar
    private let now: @Sendable () -> Date
    private let queue = SerialTaskQueue()

    public init(store: any CheckInReminderStore, profiles: any ProfileRepository, recovery: any RecoveryRepository,
                cache: any HealthSampleCache, scheduler: any CheckInReminderScheduling, notifications: (any NotificationAuthorizing)?,
                saveCheckIn: @escaping @Sendable (CheckInAnswers) async throws -> Void, calendar: Calendar,
                now: @escaping @Sendable () -> Date) {
        self.store = store
        self.profiles = profiles
        self.recovery = recovery
        self.cache = cache
        self.bedtime = HabitualBedtimeReader(cache: cache, calendar: calendar)
        self.scheduler = scheduler
        self.notifications = notifications
        self.saveCheckIn = saveCheckIn
        self.calendar = calendar
        self.now = now
    }

    public var settings: CheckInReminderSettings { store.settings }

    /// Active ou coupe le rappel. L'activer demande l'autorisation des notifications (sans effet si elle a déjà été donnée ou
    /// refusée).
    public func setEnabled(_ enabled: Bool) async {
        var settings = store.settings
        settings.enabled = enabled
        store.save(settings)
        if enabled { _ = await notifications?.requestAuthorization() }
        await reschedule()
    }

    /// Choisit l'heure du rappel ; `nil` : au réveil habituel.
    public func setChosenMinutes(_ minutes: Int?) async {
        var settings = store.settings
        settings.chosenMinutes = minutes
        store.save(settings)
        await reschedule()
    }

    /// Une réponse rapide touchée sur la notification du jour `day` : enregistre le check-in et replanifie. Rend faux, sans rien
    /// écrire, pour la notification d'un autre jour (une réponse après minuit) ou un check-in qui n'a pas pu s'enregistrer ; les
    /// rappels sont replanifiés dans tous les cas, ce qui prolonge leur suite.
    @discardableResult
    public func answer(_ quick: CheckInQuickAnswer, day: Date) async -> Bool {
        var saved = false
        if calendar.isDate(day, inSameDayAs: now()) {
            saved = (try? await saveCheckIn(quick.answers)) != nil
        }
        await reschedule()
        return saved
    }

    /// Recalcule les rappels. Un profil, un cache ou des scores illisibles laissent les rappels en attente en place.
    public func reschedule() async {
        try? await queue.run { await self.replaceReminders() }
    }

    // MARK: - Interne

    private func replaceReminders() async {
        let now = now()
        guard let context = await context(now: now) else { return }
        let settings = store.settings
        let reminders = CheckInReminderRule.reminders(settings: settings, context: context, now: now, calendar: calendar)
        // Le rappel déjà reçu ne part du centre de notifications qu'une fois inutile, pas parce que son heure est passée : une
        // replanification d'arrière-plan (déverrouillage, livraison Apple Santé) ne l'efface pas avant qu'on y réponde.
        let neededToday = CheckInReminderRule.isNeededToday(settings: settings, context: context, now: now, calendar: calendar)
        await scheduler.replaceCheckInReminders(with: reminders, clearDelivered: !neededToday)
    }

    private func context(now: Date) async -> CheckInReminderContext? {
        let today = calendar.startOfDay(for: now)
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: today),
              let watchStart = calendar.date(byAdding: .day, value: -Self.watchWindowDays, to: today) else { return nil }
        do {
            let profile = try await profiles.load()
            let hrv = try await cache.samples(kind: .sdnn, from: watchStart, to: tomorrow)
            let resting = try await cache.samples(kind: .restingHeartRate, from: watchStart, to: tomorrow)
            let checkIns = try await recovery.checkIns(from: today, to: tomorrow)
            let scores = try await recovery.dailyRecoveries(from: today, to: tomorrow)
            let plan = SleepPlan(profile: profile, wokeUp: await bedtime.nights(now: now).map(\.wokeUp), calendar: calendar)
            return CheckInReminderContext(
                lastWatchSample: (hrv + resting).map(\.start).max(), onboardingCompletedAt: profile?.onboardingCompletedAt,
                doneToday: !checkIns.isEmpty || scores.contains { !$0.isEstimated }, weekdayWake: plan.wakeMinutes(weekend: false),
                weekendWake: plan.wakeMinutes(weekend: true))
        } catch {
            return nil
        }
    }
}
