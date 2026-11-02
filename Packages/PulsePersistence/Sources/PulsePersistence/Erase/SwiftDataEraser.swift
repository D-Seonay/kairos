import Foundation
import PulseDomain
import SwiftData

/// Suppression totale (spec M2 §7.2) : magasin, instantané du widget, préférences, exports, puis Apple Santé sur demande,
/// puis notifications.
public struct SwiftDataEraser: DataEraser {
    private let container: ModelContainer
    private let defaultsSuite: String?
    private let defaultsDomain: String
    private let healthEraser: any HealthErasing
    private let notifications: (any NotificationCanceling)?
    private let widgets: (any WidgetPublishing)?
    private let exportsDirectory: URL

    /// `defaultsSuite` nil : `UserDefaults.standard` ; `defaultsDomain` : le domaine à vider (identifiant du bundle, ou la suite).
    /// `widgets` : l'instantané du widget et de l'écran verrouillé, effacé avec le magasin.
    public init(container: ModelContainer, defaultsSuite: String?, defaultsDomain: String, healthEraser: any HealthErasing,
                notifications: (any NotificationCanceling)?, widgets: (any WidgetPublishing)?, exportsDirectory: URL) {
        self.container = container
        self.defaultsSuite = defaultsSuite
        self.defaultsDomain = defaultsDomain
        self.healthEraser = healthEraser
        self.notifications = notifications
        self.widgets = widgets
        self.exportsDirectory = exportsDirectory
    }

    /// Une erreur de l'effacement Apple Santé est relancée après que tout le reste a été fait.
    public func eraseEverything(options: EraseOptions) async throws {
        try await StoreWiper(modelContainer: container).wipeAll()
        await widgets?.clear()
        let defaults = defaultsSuite.flatMap { UserDefaults(suiteName: $0) } ?? .standard
        defaults.removePersistentDomain(forName: defaultsDomain)
        if FileManager.default.fileExists(atPath: exportsDirectory.path) {
            try FileManager.default.removeItem(at: exportsDirectory)
        }
        var healthError: (any Error)?
        if options.includeAppleHealth {
            do {
                try await healthEraser.deleteAllSamplesWrittenByPulse()
            } catch {
                healthError = error
            }
        }
        await notifications?.cancelAllScheduled()
        if let healthError { throw healthError }
    }
}
