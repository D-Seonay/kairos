import CoreData
import Foundation
import os
import PulseDomain

/// Suit les synchronisations iCloud du magasin (`NSPersistentCloudKitContainer.eventChangedNotification`, que SwiftData publie
/// aussi) et garde, dans les préférences, la dernière réussie et la dernière erreur. Une notification se traite sur la file qui
/// la publie : l'état est protégé par un verrou.
public final class CloudKitSyncMonitor: CloudSyncMonitoring, @unchecked Sendable {
    static let defaultsKey = "cloudSyncStatus"

    private let defaults: UserDefaults
    private let state: OSAllocatedUnfairLock<CloudSyncStatus>
    private let center: NotificationCenter?
    private var observer: (any NSObjectProtocol)?

    /// `suiteName` nul : `UserDefaults.standard`. Sans `center`, aucun événement n'est observé (tests).
    public init(suiteName: String?, center: NotificationCenter? = .default) {
        defaults = suiteName.flatMap(UserDefaults.init(suiteName:)) ?? .standard
        let stored = defaults.data(forKey: Self.defaultsKey).flatMap { try? JSONDecoder().decode(CloudSyncStatus.self, from: $0) }
        state = OSAllocatedUnfairLock(initialState: stored ?? CloudSyncStatus())
        self.center = center
        observer = center?.addObserver(forName: NSPersistentCloudKitContainer.eventChangedNotification, object: nil,
                                       queue: nil) { [weak self] notification in
            let key = NSPersistentCloudKitContainer.eventNotificationUserInfoKey
            guard let event = notification.userInfo?[key] as? NSPersistentCloudKitContainer.Event,
                  let summary = Self.summary(of: event) else { return }
            self?.record(summary)
        }
    }

    deinit {
        if let observer { center?.removeObserver(observer) }
    }

    public func status() async -> CloudSyncStatus? {
        state.withLock { $0 }
    }

    /// Note une synchronisation finie et l'enregistre.
    func record(_ event: CloudSyncEvent) {
        let status = state.withLock { status in
            status.record(event)
            return status
        }
        if let data = try? JSONEncoder().encode(status) { defaults.set(data, forKey: Self.defaultsKey) }
    }

    /// Un événement fini ; `nil` tant qu'il tourne. Une mise en place réussie n'est pas une synchronisation : elle est ignorée.
    static func summary(of event: NSPersistentCloudKitContainer.Event) -> CloudSyncEvent? {
        guard let endDate = event.endDate else { return nil }
        if event.succeeded {
            return event.type == .setup ? nil : CloudSyncEvent(endDate: endDate, problem: nil)
        }
        return CloudSyncEvent(endDate: endDate, problem: CloudSyncErrorClassifier.classify(event.error))
    }
}
