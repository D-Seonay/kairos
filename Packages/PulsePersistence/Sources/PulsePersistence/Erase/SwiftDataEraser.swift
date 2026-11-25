import Foundation
import PulseDomain
import SwiftData

/// Suppression totale (spec M2 §7.2) : magasin, photos de corps et leur export, instantané du widget, préférences, exports et
/// fichier GPX à partager, puis Apple Santé sur demande, puis notifications.
public struct SwiftDataEraser: DataEraser {
    private let container: ModelContainer
    private let defaultsSuite: String?
    private let defaultsDomain: String
    private let healthEraser: any HealthErasing
    private let notifications: (any NotificationCanceling)?
    private let widgets: (any WidgetPublishing)?
    private let exportsDirectory: URL
    private let bodyPhotos: (any BodyPhotoStore)?
    private let bodyPhotoExportDirectory: URL?
    private let runGPXDirectory: URL?

    /// `defaultsSuite` nil : `UserDefaults.standard` ; `defaultsDomain` : le domaine à vider (identifiant du bundle, ou la suite).
    /// `widgets` : l'instantané du widget et de l'écran verrouillé, effacé avec le magasin.
    /// `bodyPhotos` : le dépôt de fichiers des photos de corps, hors du magasin, vidé juste après lui.
    /// `bodyPhotoExportDirectory` : le dossier de l'archive d'export des photos de corps, supprimé avec elles.
    /// `runGPXDirectory` : le dossier du fichier GPX d'une course à partager (un tracé, donc des positions), supprimé avec les
    /// exports.
    public init(container: ModelContainer, defaultsSuite: String?, defaultsDomain: String, healthEraser: any HealthErasing,
                notifications: (any NotificationCanceling)?, widgets: (any WidgetPublishing)?, exportsDirectory: URL,
                bodyPhotos: (any BodyPhotoStore)? = nil, bodyPhotoExportDirectory: URL? = nil, runGPXDirectory: URL? = nil) {
        self.container = container
        self.defaultsSuite = defaultsSuite
        self.defaultsDomain = defaultsDomain
        self.healthEraser = healthEraser
        self.notifications = notifications
        self.widgets = widgets
        self.exportsDirectory = exportsDirectory
        self.bodyPhotos = bodyPhotos
        self.bodyPhotoExportDirectory = bodyPhotoExportDirectory
        self.runGPXDirectory = runGPXDirectory
    }

    /// Une erreur de l'effacement des photos de corps ou d'Apple Santé est relancée après que tout le reste a été fait.
    public func eraseEverything(options: EraseOptions) async throws {
        try await StoreWiper(modelContainer: container).wipeAll()
        var bodyPhotosError: (any Error)?
        do {
            try await bodyPhotos?.deleteAll()
        } catch {
            bodyPhotosError = error
        }
        do {
            if let bodyPhotoExportDirectory, FileManager.default.fileExists(atPath: bodyPhotoExportDirectory.path) {
                try FileManager.default.removeItem(at: bodyPhotoExportDirectory)
            }
        } catch {
            bodyPhotosError = bodyPhotosError ?? error
        }
        await widgets?.clear()
        let defaults = defaultsSuite.flatMap { UserDefaults(suiteName: $0) } ?? .standard
        defaults.removePersistentDomain(forName: defaultsDomain)
        for directory in [exportsDirectory, runGPXDirectory].compactMap({ $0 })
        where FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.removeItem(at: directory)
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
        if let bodyPhotosError { throw bodyPhotosError }
        if let healthError { throw healthError }
    }
}
