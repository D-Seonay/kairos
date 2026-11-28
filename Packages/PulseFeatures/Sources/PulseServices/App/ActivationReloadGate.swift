import Foundation

/// Décide si un retour au premier plan relit tout (accueil, séance, planning, compléments, rappels, stats, profil) : au premier
/// retour, quand le jour civil a changé, quand une écriture SwiftData, un import iCloud ou un changement de fuseau a été noté, ou
/// quand la dernière relecture a plus de `maxAge`. Deux retours rapprochés (centre de notifications, widget) ne relisent qu'une fois.
public struct ActivationReloadGate: Sendable {
    public static let defaultMaxAge: TimeInterval = 10 * 60

    public let maxAge: TimeInterval
    /// Le début de la dernière relecture terminée.
    public private(set) var lastReload: Date?
    /// Un enregistrement SwiftData noté depuis la dernière relecture.
    public private(set) var hasPendingSave = false
    /// Un import iCloud ou un changement de fuseau noté depuis le début de la dernière relecture.
    public private(set) var hasPendingExternalChange = false
    public private(set) var isReloading = false

    public init(maxAge: TimeInterval = defaultMaxAge) {
        self.maxAge = maxAge
    }

    /// Un enregistrement SwiftData : le prochain retour relit tout, sauf s'il vient de la relecture en cours.
    public mutating func noteSave() {
        hasPendingSave = true
    }

    /// Un import iCloud (un autre appareil a écrit) ou un changement de fuseau : le prochain retour relit tout, même s'il arrive
    /// pendant une relecture, qui a pu lire avant lui.
    public mutating func noteExternalChange() {
        hasPendingExternalChange = true
    }

    /// Vrai si le retour à `now` doit relire ; la relecture commence alors, et un second retour pendant qu'elle tourne est ignoré.
    /// Une dernière relecture « dans le futur » (horloge reculée) compte comme trop vieille.
    public mutating func beginReload(at now: Date, calendar: Calendar) -> Bool {
        guard !isReloading else { return false }
        let due: Bool
        if let lastReload {
            let age = now.timeIntervalSince(lastReload)
            due = hasPendingSave || hasPendingExternalChange || age >= maxAge || age < 0
                || !calendar.isDate(now, inSameDayAs: lastReload)
        } else {
            due = true
        }
        if due {
            isReloading = true
            // La relecture lit ce qui est arrivé jusqu'ici ; ce qui arrivera pendant qu'elle tourne restera à lire.
            hasPendingExternalChange = false
        }
        return due
    }

    /// La relecture commencée à `start` est finie. Les enregistrements notés pendant qu'elle tournait sont les siens (le score du
    /// jour qu'elle vient d'enregistrer) : ils sont oubliés. Un import iCloud ou un changement de fuseau arrivé entre-temps reste
    /// noté : le prochain retour relit.
    public mutating func endReload(at start: Date) {
        lastReload = start
        hasPendingSave = false
        isReloading = false
    }
}
