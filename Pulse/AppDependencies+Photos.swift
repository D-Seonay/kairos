import Foundation
import PulseDomain
import PulsePersistence
import PulseServices
import SwiftData

// MARK: - Photos

extension AppDependencies {
    /// Le dossier des photos de corps de l'app réelle : dans Application Support, protégé et exclu des sauvegardes par le dépôt.
    static var bodyPhotosDirectory: URL {
        URL.applicationSupportDirectory.appending(path: "Pulse/BodyPhotos", directoryHint: .isDirectory)
    }

    /// Les photos de séance et de corps de l'app, assemblées une fois au lancement.
    struct PhotoDependencies: Sendable {
        /// Les photos de séance, synchronisées : la séance en direct les supprime avec une séance abandonnée.
        let sessionRepository: any SessionPhotoRepository
        /// Le seul chemin vers les photos de séance : séance en direct, récaps et détails des séances.
        let sessions: SessionPhotoService
        /// Le seul chemin vers les photos de corps, au premier plan seulement. Son dépôt est celui du câblage, que la suppression
        /// totale vide aussi : deux dépôts sur un même dossier perdraient des mises à jour de l'index.
        let body: BodyPhotoService
        /// « Verrouiller avec Face ID », dans la suite de préférences que la suppression totale vide.
        let bodyLock: any BodyPhotoLockStore
        let ownerAuthentication: any DeviceOwnerAuthenticating
        /// Le rappel de reprendre des photos de corps : son réglage dans la suite de préférences que la suppression totale vide,
        /// et ses notifications locales neutres.
        let reminders: BodyPhotoReminders

        init(_ wiring: Wiring, container: ModelContainer, measurements: any BodyMeasurementRepository) {
            let timeZone = wiring.calendar.timeZone
            sessionRepository = SwiftDataSessionPhotoRepository(modelContainer: container)
            sessions = SessionPhotoService(repository: sessionRepository, timeZone: timeZone, now: wiring.now)
            body = BodyPhotoService(store: wiring.bodyPhotos, measurements: measurements, calendar: wiring.calendar,
                                    timeZone: timeZone, now: wiring.now)
            bodyLock = UserDefaultsBodyPhotoLockStore(suiteName: wiring.defaultsSuite)
            reminders = BodyPhotoReminders(store: UserDefaultsBodyPhotoReminderStore(suiteName: wiring.defaultsSuite),
                                           scheduler: wiring.bodyPhotoReminders, notifications: wiring.notifications,
                                           notificationStatus: wiring.notificationStatus, calendar: wiring.calendar)
            ownerAuthentication = Self.ownerAuthentication(for: wiring.launch)
        }

        /// Face ID ou le code de l'iPhone. Dans les modes des tests d'interface (`-PulseStore inMemory|disk`, Debug seulement), une
        /// doublure qui ne présente jamais la demande système. En Release, les options de lancement ne sont pas lues et la
        /// doublure n'est pas compilée : le vrai Face ID, toujours.
        static func ownerAuthentication(for launch: LaunchOptions) -> any DeviceOwnerAuthenticating {
            #if DEBUG
            if launch.storeInMemory || launch.storeOnDisk {
                return UITestOwnerAuthenticator(scenario: launch.ownerAuthentication)
            }
            #endif
            return LocalAuthenticationOwnerAuthenticator()
        }
    }
}
