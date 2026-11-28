import Foundation
import PulseDomain
import PulseServices
import SwiftUI
import TrainFeature

/// Tout ce dont l'onglet Profil a besoin du dehors : le résumé, les pesées, les réglages, l'état d'Apple Santé, les données
/// stockées (inspection, export, suppression), ce que seule l'app sait (autorisation des notifications, passage du jour,
/// version, politique de confidentialité), les réglages de la course, les photos de corps et l'horloge.
public struct ProfileEnvironment: Sendable {
    public var profile: ProfileService
    public var body: BodyService
    public var settings: SettingsService
    public var healthCache: any HealthSampleCache
    public var inspector: any StoreInspector
    public var exporter: any DataExporter
    public var eraser: any DataEraser
    /// L'autorisation des notifications de Pulse dans les réglages d'iOS.
    public var notificationStatus: @Sendable () async -> NotificationAuthorizationStatus
    /// Demande l'autorisation des notifications à iOS ; vrai si elle est accordée.
    public var requestNotificationAuthorization: @Sendable () async -> Bool
    /// « Relire maintenant » : lance le passage du jour.
    public var refreshHealth: @Sendable () async -> Void
    /// « 1.0.2 (14) ».
    public var appVersion: String
    /// Lue dans l'Info.plist ; `nil` tant qu'elle est vide (spec M7 §16).
    public var privacyPolicyURL: URL?
    public var calendar: Calendar
    public var now: @Sendable () -> Date
    /// Les réglages de la course, par appareil : pour l'instant les annonces vocales à chaque kilomètre.
    public var runPreferences: any RunPreferencesStore
    /// Les photos de corps ; `nil` : la ligne « Photos de corps » n'apparaît pas.
    public var bodyPhotos: BodyPhotoService?
    /// Face ID ou le code de l'iPhone, qui verrouille les photos de corps. Sans lui, la ligne « Photos de corps » n'apparaît pas
    /// et l'écran, s'il était ouvert quand même, resterait verrouillé.
    public var ownerAuthentication: (any DeviceOwnerAuthenticating)?
    /// Le réglage « Verrouiller avec Face ID », par appareil.
    public var bodyPhotoLock: any BodyPhotoLockStore
    /// Le rappel de reprendre des photos de corps, par appareil ; `nil` : l'écran n'offre pas de rappel.
    public var bodyPhotoReminders: BodyPhotoReminders?
    /// L'environnement de l'onglet Séance, pour ouvrir la progression d'un levé depuis le mur des records, comme Stats → Records ;
    /// `nil` : les lignes du mur ne s'ouvrent pas.
    public var train: TrainEnvironment?
    /// Le plan du sommeil d'aujourd'hui (objectif, réveils, coucher conseillé) ; `nil` : le pied de la section « Sommeil » invite à
    /// choisir un réveil.
    public var sleepPlan: @Sendable () async -> SleepPlan?
    /// La demande d'accès à Apple Santé, pour « Connecter Apple Santé » dans la section Apple Santé ; `nil` : la section ne
    /// l'offre pas.
    public var healthAccess: HealthAccess?
    /// Le rappel de check-in pour qui n'a pas de montre, réglé dans les notifications ; `nil` : la ligne n'apparaît pas.
    public var checkInReminders: CheckInReminderService?
    /// La dernière synchronisation iCloud réussie et la dernière erreur, pour « Mes données ».
    public var cloudSync: any CloudSyncMonitoring

    /// Les photos de corps ne s'offrent qu'avec leur service et leur authentificateur : jamais d'écran ouvert sans verrou.
    public var offersBodyPhotos: Bool {
        bodyPhotos != nil && ownerAuthentication != nil
    }

    public init(profile: ProfileService, body: BodyService, settings: SettingsService, healthCache: any HealthSampleCache,
                inspector: any StoreInspector, exporter: any DataExporter, eraser: any DataEraser,
                notificationStatus: @escaping @Sendable () async -> NotificationAuthorizationStatus,
                requestNotificationAuthorization: @escaping @Sendable () async -> Bool,
                refreshHealth: @escaping @Sendable () async -> Void,
                appVersion: String, privacyPolicyURL: URL?, calendar: Calendar, now: @escaping @Sendable () -> Date,
                runPreferences: any RunPreferencesStore = InMemoryRunPreferencesStore(), bodyPhotos: BodyPhotoService? = nil,
                ownerAuthentication: (any DeviceOwnerAuthenticating)? = nil,
                bodyPhotoLock: any BodyPhotoLockStore = InMemoryBodyPhotoLockStore(),
                bodyPhotoReminders: BodyPhotoReminders? = nil, train: TrainEnvironment? = nil,
                sleepPlan: @escaping @Sendable () async -> SleepPlan? = { nil }, healthAccess: HealthAccess? = nil,
                checkInReminders: CheckInReminderService? = nil,
                cloudSync: any CloudSyncMonitoring = NoCloudSync()) {
        self.profile = profile
        self.body = body
        self.settings = settings
        self.healthCache = healthCache
        self.inspector = inspector
        self.exporter = exporter
        self.eraser = eraser
        self.notificationStatus = notificationStatus
        self.requestNotificationAuthorization = requestNotificationAuthorization
        self.refreshHealth = refreshHealth
        self.appVersion = appVersion
        self.privacyPolicyURL = privacyPolicyURL
        self.calendar = calendar
        self.now = now
        self.runPreferences = runPreferences
        self.bodyPhotos = bodyPhotos
        self.ownerAuthentication = ownerAuthentication
        self.bodyPhotoLock = bodyPhotoLock
        self.bodyPhotoReminders = bodyPhotoReminders
        self.train = train
        self.sleepPlan = sleepPlan
        self.healthAccess = healthAccess
        self.checkInReminders = checkInReminders
        self.cloudSync = cloudSync
    }
}

/// Les écrans qui restent dans la cible app (spec M7 §16) : le diagnostic Apple Santé, le debug « Données » et la confirmation de
/// suppression. L'onglet Profil les reçoit plutôt que de les déplacer dans un package.
public struct ProfileAppScreens {
    public var healthDiagnostics: () -> AnyView
    /// `nil` en Release : l'écran de debug n'existe qu'en DEBUG.
    public var dataDebug: (() -> AnyView)?
    /// `onErased` part une fois tout supprimé.
    public var eraseConfirmation: (_ onErased: @escaping () async -> Void) -> AnyView

    public init(healthDiagnostics: @escaping () -> AnyView, dataDebug: (() -> AnyView)?,
                eraseConfirmation: @escaping (_ onErased: @escaping () async -> Void) -> AnyView) {
        self.healthDiagnostics = healthDiagnostics
        self.dataDebug = dataDebug
        self.eraseConfirmation = eraseConfirmation
    }
}
