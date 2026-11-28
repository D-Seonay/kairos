import CoreData
import Foundation
import SwiftData

/// Prévient quand les écrans ont peut-être des données périmées : un enregistrement SwiftData (passage du jour en arrière-plan,
/// action « Pris » d'une notification, autre écran), un import iCloud réussi (un autre appareil a écrit) ou un changement de fuseau
/// (le jour civil a pu changer). Les brouillons de la séance et de la course, réécrits toutes les quelques secondes, ne comptent
/// pas. `onChange` part sur la file qui publie la notification.
public final class DataChangeObserver: @unchecked Sendable {
    /// Les modèles réécrits en continu pendant une séance ou une course, que les écrans ne relisent pas au retour dans l'app.
    static let transientEntities: Set<String> = [
        String(describing: StoredRunDraft.self), String(describing: StoredRunDraftChunk.self),
        String(describing: StoredActiveSessionSnapshot.self)
    ]
    private static let identifierKeys = [ModelContext.NotificationKey.insertedIdentifiers, .updatedIdentifiers,
                                         .deletedIdentifiers].map(\.rawValue)

    private let center: NotificationCenter
    /// Écrit une fois, dans `init` ; d'où `@unchecked Sendable`.
    private let observers: [any NSObjectProtocol]

    public init(center: NotificationCenter = .default, onChange: @escaping @Sendable () -> Void) {
        self.center = center
        observers = [
            center.addObserver(forName: ModelContext.didSave, object: nil, queue: nil) { notification in
                guard Self.isRelevant(entityNames: Self.entityNames(in: notification.userInfo)) else { return }
                onChange()
            },
            center.addObserver(forName: NSPersistentCloudKitContainer.eventChangedNotification, object: nil,
                               queue: nil) { notification in
                let key = NSPersistentCloudKitContainer.eventNotificationUserInfoKey
                guard let event = notification.userInfo?[key] as? NSPersistentCloudKitContainer.Event,
                      event.type == .import, event.endDate != nil, event.succeeded else { return }
                onChange()
            },
            center.addObserver(forName: .NSSystemTimeZoneDidChange, object: nil, queue: nil) { _ in onChange() }
        ]
    }

    deinit {
        for observer in observers { center.removeObserver(observer) }
    }

    /// Vrai si l'enregistrement touche autre chose que les brouillons ; un enregistrement dont on ne sait rien compte.
    static func isRelevant(entityNames: Set<String>?) -> Bool {
        guard let entityNames else { return true }
        return !entityNames.isSubset(of: transientEntities)
    }

    /// Les modèles touchés par un `ModelContext.didSave` ; `nil` si la notification ne le dit pas.
    static func entityNames(in userInfo: [AnyHashable: Any]?) -> Set<String>? {
        guard let userInfo else { return nil }
        let identifiers = identifierKeys.compactMap { userInfo[$0] as? [PersistentIdentifier] }
        guard !identifiers.isEmpty else { return nil }
        return Set(identifiers.joined().map(\.entityName))
    }
}
