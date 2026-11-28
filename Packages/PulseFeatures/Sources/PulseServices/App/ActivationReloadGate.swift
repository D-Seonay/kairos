import Foundation

/// Décide si un retour au premier plan relit tout (accueil, séance, planning, compléments, rappels, stats, profil) : au premier
/// retour, quand le jour civil a changé, quand une écriture SwiftData, un import iCloud ou un changement de fuseau a été noté, ou
/// quand la dernière relecture a plus de `maxAge`. Deux retours rapprochés (centre de notifications, widget) ne relisent qu'une fois.
public struct ActivationReloadGate: Sendable {
    public static let defaultMaxAge: TimeInterval = 10 * 60

    public let maxAge: TimeInterval
    /// Le début de la dernière relecture terminée.
    public private(set) var lastReload: Date?
    public private(set) var hasPendingChange = false
    public private(set) var isReloading = false

    public init(maxAge: TimeInterval = defaultMaxAge) {
        self.maxAge = maxAge
    }

    /// Une donnée a changé hors de la relecture : le prochain retour relit tout.
    public mutating func noteChange() {
        hasPendingChange = true
    }

    /// Vrai si le retour à `now` doit relire ; la relecture commence alors, et un second retour pendant qu'elle tourne est ignoré.
    /// Une dernière relecture « dans le futur » (horloge reculée) compte comme trop vieille.
    public mutating func beginReload(at now: Date, calendar: Calendar) -> Bool {
        guard !isReloading else { return false }
        let due: Bool
        if let lastReload {
            let age = now.timeIntervalSince(lastReload)
            due = hasPendingChange || age >= maxAge || age < 0 || !calendar.isDate(now, inSameDayAs: lastReload)
        } else {
            due = true
        }
        if due { isReloading = true }
        return due
    }

    /// La relecture commencée à `start` est finie. Les changements notés pendant qu'elle tournait sont les siens (le score du jour
    /// qu'elle vient d'enregistrer) : ils sont oubliés, la limite d'âge rattrape un import iCloud arrivé au même moment.
    public mutating func endReload(at start: Date) {
        lastReload = start
        hasPendingChange = false
        isReloading = false
    }
}
