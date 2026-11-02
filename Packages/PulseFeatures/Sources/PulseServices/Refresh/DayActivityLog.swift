import Foundation
import Synchronization

/// Ce que l'app retient de son activité pour décider de la notification du matin : la dernière ouverture, et le dernier jour annoncé.
public protocol DayActivityLog: Sendable {
    func lastOpenedAt() -> Date?
    func markOpened(at: Date)
    func lastNotifiedDay() -> Date?
    func markNotified(day: Date)
}

/// Journal gardé dans `UserDefaults`. Seul le nom de la suite est retenu : `UserDefaults` n'est pas `Sendable`.
/// Les deux clés vivent dans le domaine de la suite, que la suppression totale vide en entier.
public final class UserDefaultsDayActivityLog: DayActivityLog {
    static let lastOpenedAtKey = "pulse.lastOpenedAt"
    static let lastNotifiedDayKey = "pulse.lastNotifiedDay"

    private let suiteName: String?

    public init(suiteName: String?) {
        self.suiteName = suiteName
    }

    private var defaults: UserDefaults {
        suiteName.flatMap(UserDefaults.init(suiteName:)) ?? .standard
    }

    public func lastOpenedAt() -> Date? {
        defaults.object(forKey: Self.lastOpenedAtKey) as? Date
    }

    public func markOpened(at date: Date) {
        defaults.set(date, forKey: Self.lastOpenedAtKey)
    }

    public func lastNotifiedDay() -> Date? {
        defaults.object(forKey: Self.lastNotifiedDayKey) as? Date
    }

    public func markNotified(day: Date) {
        defaults.set(day, forKey: Self.lastNotifiedDayKey)
    }
}

/// Journal en mémoire, pour les tests et les aperçus.
public final class InMemoryDayActivityLog: DayActivityLog {
    private struct State {
        var lastOpenedAt: Date?
        var lastNotifiedDay: Date?
    }

    private let state = Mutex(State())

    public init() {}

    public func lastOpenedAt() -> Date? {
        state.withLock { $0.lastOpenedAt }
    }

    public func markOpened(at date: Date) {
        state.withLock { $0.lastOpenedAt = date }
    }

    public func lastNotifiedDay() -> Date? {
        state.withLock { $0.lastNotifiedDay }
    }

    public func markNotified(day: Date) {
        state.withLock { $0.lastNotifiedDay = day }
    }
}
