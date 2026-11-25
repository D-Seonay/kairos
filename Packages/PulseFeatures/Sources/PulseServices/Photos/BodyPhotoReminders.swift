import Foundation
import PulseDomain
import Synchronization

/// Le rythme du rappel de photos de corps, réglé dans l'écran Photos de corps.
public enum BodyPhotoReminderInterval: String, Sendable, CaseIterable {
    case off
    case everyTwoWeeks
    case monthly
}

/// Les dates du rappel de photos de corps. Pur : les jours et l'heure viennent du calendrier donné.
public enum BodyPhotoReminderPlanner {
    /// L'heure du rappel, le matin : celle d'une photo de suivi habituelle, à jeun.
    public static let hour = 9
    /// Les rappels planifiés d'avance : un rappel ignoré revient à l'échéance suivante, jusqu'à trois fois.
    public static let count = 3

    /// Une période après la dernière photo (ou après maintenant sans photo), à 9 h, puis toutes les périodes suivantes. Une
    /// échéance déjà passée revient au prochain 9 h. Aucune date quand le rappel est désactivé.
    public static func dates(interval: BodyPhotoReminderInterval, lastPhoto: Date?, now: Date, calendar: Calendar) -> [Date] {
        guard interval != .off else { return [] }
        let base = calendar.startOfDay(for: lastPhoto.map { min($0, now) } ?? now)
        guard let due = adding(interval, times: 1, to: base, calendar: calendar).flatMap({ atHour($0, calendar: calendar) }),
              let first = due > now ? due : nextHour(after: now, calendar: calendar) else { return [] }
        let firstDay = calendar.startOfDay(for: first)
        return (0..<count).compactMap { index in
            adding(interval, times: index, to: firstDay, calendar: calendar).flatMap { atHour($0, calendar: calendar) }
        }
    }

    private static func adding(_ interval: BodyPhotoReminderInterval, times: Int, to day: Date, calendar: Calendar) -> Date? {
        switch interval {
        case .off: nil
        case .everyTwoWeeks: calendar.date(byAdding: .day, value: 14 * times, to: day)
        case .monthly: calendar.date(byAdding: .month, value: times, to: day)
        }
    }

    private static func atHour(_ day: Date, calendar: Calendar) -> Date? {
        calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day)
    }

    /// Aujourd'hui à 9 h s'il est encore à venir, sinon demain à 9 h.
    private static func nextHour(after now: Date, calendar: Calendar) -> Date? {
        let today = calendar.startOfDay(for: now)
        if let morning = atHour(today, calendar: calendar), morning > now { return morning }
        return calendar.date(byAdding: .day, value: 1, to: today).flatMap { atHour($0, calendar: calendar) }
    }
}

/// Le réglage du rappel de photos de corps, gardé par appareil comme les photos.
public protocol BodyPhotoReminderStore: Sendable {
    /// Désactivé par défaut.
    var interval: BodyPhotoReminderInterval { get }
    func setInterval(_ interval: BodyPhotoReminderInterval)
}

/// Réglage gardé dans `UserDefaults`. Seul le nom de la suite est retenu : `UserDefaults` n'est pas `Sendable`. La clé vit dans
/// le domaine de la suite, que la suppression totale vide en entier.
public final class UserDefaultsBodyPhotoReminderStore: BodyPhotoReminderStore {
    static let intervalKey = "pulse.bodyPhotos.reminderInterval"

    private let suiteName: String?

    public init(suiteName: String?) {
        self.suiteName = suiteName
    }

    private var defaults: UserDefaults {
        suiteName.flatMap(UserDefaults.init(suiteName:)) ?? .standard
    }

    public var interval: BodyPhotoReminderInterval {
        defaults.string(forKey: Self.intervalKey).flatMap(BodyPhotoReminderInterval.init(rawValue:)) ?? .off
    }

    public func setInterval(_ interval: BodyPhotoReminderInterval) {
        defaults.set(interval.rawValue, forKey: Self.intervalKey)
    }
}

/// Réglage en mémoire, pour les tests et les aperçus.
public final class InMemoryBodyPhotoReminderStore: BodyPhotoReminderStore {
    private let stored: Mutex<BodyPhotoReminderInterval>

    public init(interval: BodyPhotoReminderInterval = .off) {
        stored = Mutex(interval)
    }

    public var interval: BodyPhotoReminderInterval {
        stored.withLock { $0 }
    }

    public func setInterval(_ interval: BodyPhotoReminderInterval) {
        stored.withLock { $0 = interval }
    }
}

/// Le rappel de reprendre des photos de corps : le réglage, l'autorisation des notifications et la planification. L'écran
/// Photos de corps le replanifie quand le réglage change et après chaque photo ajoutée ou supprimée ; le retour au premier plan
/// le relance quand toutes ses échéances sont passées. Les planifications passent l'une après l'autre par une même file, et
/// chacune relit le réglage : la dernière demande l'emporte (« Tous les mois » puis vite « Désactivé » ne laisse rien).
public struct BodyPhotoReminders: Sendable {
    private let store: any BodyPhotoReminderStore
    private let scheduler: any BodyPhotoReminderScheduling
    private let notifications: (any NotificationAuthorizing)?
    private let notificationStatus: (@Sendable () async -> NotificationAuthorizationStatus)?
    private let calendar: Calendar
    /// Partagée par les copies : l'app n'en crée qu'une, que l'écran reçoit par l'environnement du profil.
    private let queue = SerialTaskQueue()

    public init(store: any BodyPhotoReminderStore, scheduler: any BodyPhotoReminderScheduling,
                notifications: (any NotificationAuthorizing)?,
                notificationStatus: (@Sendable () async -> NotificationAuthorizationStatus)? = nil, calendar: Calendar) {
        self.store = store
        self.scheduler = scheduler
        self.notifications = notifications
        self.notificationStatus = notificationStatus
        self.calendar = calendar
    }

    public var interval: BodyPhotoReminderInterval { store.interval }

    /// Enregistre le rythme et replanifie. Activer le rappel demande l'autorisation des notifications (sans effet si elle a déjà
    /// été donnée ou refusée).
    public func setInterval(_ interval: BodyPhotoReminderInterval, lastPhoto: Date?, now: Date) async {
        store.setInterval(interval)
        if interval != .off { _ = await notifications?.requestAuthorization() }
        await reschedule(lastPhoto: lastPhoto, now: now)
    }

    /// Replanifie depuis la dernière photo : une photo prise repousse le rappel suivant.
    public func reschedule(lastPhoto: Date?, now: Date) async {
        try? await queue.run { [store, scheduler, calendar] in
            await scheduler.replaceBodyPhotoReminders(at: BodyPhotoReminderPlanner.dates(
                interval: store.interval, lastPhoto: lastPhoto, now: now, calendar: calendar))
        }
    }

    /// Au lancement et au retour au premier plan : un rappel actif dont toutes les échéances sont passées repart de maintenant,
    /// sans lire les photos (leurs dates restent dans la section verrouillée, jamais dans les préférences).
    public func resumeIfIdle(now: Date) async {
        try? await queue.run { [store, scheduler, calendar] in
            guard store.interval != .off, await scheduler.pendingBodyPhotoReminderCount() == 0 else { return }
            await scheduler.replaceBodyPhotoReminders(at: BodyPhotoReminderPlanner.dates(
                interval: store.interval, lastPhoto: nil, now: now, calendar: calendar))
        }
    }

    /// Vrai quand les notifications de Pulse sont coupées dans les réglages d'iOS : le rappel n'apparaîtrait pas.
    public func notificationsDenied() async -> Bool {
        await notificationStatus?() == .denied
    }
}
