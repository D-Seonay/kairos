import Foundation
import Observation
import PulseDomain
import PulseServices
import SwiftUI

/// L'état de la section Photos de corps : le verrou (Face ID ou code), le cache quand l'app n'est plus active, la liste par jour,
/// l'ajout, la suppression, l'export et le réglage du verrou. Aucun fichier n'est lu tant que la section est verrouillée : la
/// liste et les vignettes ne se chargent qu'une fois déverrouillée, et elles sont oubliées dès qu'elle se reverrouille.
@MainActor @Observable
public final class BodyPhotosModel {
    public private(set) var lockState: BodyPhotosLockState = .locked
    /// Vrai dès que la scène n'est plus active (sélecteur d'apps, centre de contrôle, appel) : le cache couvre la section.
    public private(set) var isCovered = false
    public private(set) var days: [BodyPhotoDay] = []
    public private(set) var thumbnails: [UUID: Data] = [:]
    /// Vrai tant que l'apparition n'a pas dit le contraire : sans code, ni verrou ni chiffrement. Sans authentificateur, il reste
    /// vrai : la section reste verrouillée plutôt que de s'ouvrir.
    public private(set) var hasPasscode = true
    /// Vrai pendant une demande d'authentification : l'interrupteur et « Déverrouiller » attendent.
    public private(set) var isAuthenticating = false
    public private(set) var isExporting = false
    public private(set) var errorMessage: String?
    /// La dernière annonce VoiceOver ; la vue la poste.
    public private(set) var announcement: String?
    /// Change à chaque annonce : deux « Photo ajoutée » de suite se disent deux fois.
    public private(set) var announcementSerial = 0
    /// Le réglage « Verrouiller avec Face ID », recopié du magasin pour que la vue le suive.
    private var lockSetting: Bool
    /// Le rythme du rappel de photos, recopié du réglage pour que la vue le suive ; désactivé sans rappels branchés.
    public internal(set) var reminderInterval: BodyPhotoReminderInterval
    /// Vrai quand les notifications de Pulse sont coupées dans les réglages d'iOS : le rappel n'apparaîtrait pas.
    public internal(set) var notificationsDenied = false

    @ObservationIgnored private let service: BodyPhotoService
    @ObservationIgnored private let authentication: (any DeviceOwnerAuthenticating)?
    @ObservationIgnored private let lock: any BodyPhotoLockStore
    /// Le rappel de reprendre des photos ; `nil` : pas de réglage de rappel.
    @ObservationIgnored let reminders: BodyPhotoReminders?
    @ObservationIgnored let calendar: Calendar
    @ObservationIgnored private let now: @Sendable () -> Date
    @ObservationIgnored private var phase: ScenePhase = .active
    /// Vrai entre `appear` et `disappear` : une authentification qui aboutit après la sortie de la section ne déverrouille rien.
    @ObservationIgnored private var isInSection = false
    /// Vrai quand l'arrière-plan vient de reverrouiller : le retour au premier plan redemande Face ID, une seule fois.
    @ObservationIgnored private var promptsOnActive = false
    /// L'archive d'export pas encore enregistrée ni abandonnée.
    @ObservationIgnored private var pendingExport: URL?
    /// La demande de Face ID lancée au retour au premier plan (les tests l'attendent).
    @ObservationIgnored private(set) var pendingUnlock: Task<Void, Never>?
    /// Les écrans de la section à l'écran (liste, comparaison, visionneuse).
    @ObservationIgnored private var visibleScreens = 0
    /// Le reverrouillage qui attend qu'aucun écran de la section ne revienne (les tests l'attendent).
    @ObservationIgnored private(set) var pendingLeave: Task<Void, Never>?

    public init(service: BodyPhotoService, authentication: (any DeviceOwnerAuthenticating)?, lock: any BodyPhotoLockStore,
                reminders: BodyPhotoReminders? = nil, calendar: Calendar, now: @escaping @Sendable () -> Date) {
        self.service = service
        self.authentication = authentication
        self.lock = lock
        self.reminders = reminders
        self.calendar = calendar
        self.now = now
        lockSetting = lock.isLockEnabled
        reminderInterval = reminders?.interval ?? .off
    }

    /// Le verrou est actif : il y a un code et le réglage n'est pas coupé.
    public var isLockEnabled: Bool { hasPasscode && lockSetting }

    /// Vrai quand le cache doit couvrir la section : scène inactive, ou section verrouillée.
    public var showsCover: Bool { isCovered || lockState == .locked }

    /// Les fichiers ne se lisent que déverrouillé, ou sans code (rien à déverrouiller).
    var canReadFiles: Bool { lockState != .locked }

    /// Maintenant : la borne de la date d'une photo.
    public var today: Date { now() }

    /// Les photos de la liste, du jour le plus récent au plus ancien, dans l'ordre face, profil, dos.
    public var photos: [BodyPhoto] {
        days.flatMap { day in BodyPose.allCases.compactMap { day.photos[$0] } }
    }

    /// Vrai quand une pose a au moins deux dates.
    public var canCompare: Bool {
        !BodyPhotoTimeline.comparablePoses(photos, calendar: calendar).isEmpty
    }

    /// Le texte fixe, la ligne « sans code » si besoin, puis la dernière prise s'il y a des photos.
    public var headerLines: [String] {
        var lines = [PhotoText.bodyNotice]
        if !hasPasscode { lines.append(PhotoText.noPasscodeNotice) }
        if let last = days.first?.day { lines.append(PhotoText.lastShot(last, now: now(), calendar: calendar)) }
        return lines
    }

    // MARK: Verrou

    /// À l'apparition de la section : relit la présence d'un code, authentifie si le verrou est actif, puis charge. Revenir sur
    /// l'écran déjà déverrouillé (retour de la comparaison) recharge sans redemander.
    /// Sans authentificateur (un branchement oublié), la section reste verrouillée et ne se déverrouille jamais.
    public func appear() async {
        isInSection = true
        guard let authentication else {
            hasPasscode = true
            if lockState != .locked { relock() }
            return
        }
        hasPasscode = await authentication.isAvailable()
        if !hasPasscode {
            lockState = .unavailable
        } else if !lockSetting {
            lockState = .unlocked
        } else if lockState == .unavailable {
            // Un code vient d'être créé : ce qui était lu sans verrou est oublié.
            relock()
        }
        if lockState == .locked {
            await unlock()
        } else {
            await load()
        }
    }

    /// Demande Face ID (ou le code). En cas d'échec ou d'annulation, la section reste verrouillée et propose « Déverrouiller ».
    public func unlock() async {
        guard lockState == .locked, isInSection, !isAuthenticating else { return }
        guard await authenticate() else { return }
        guard lockState == .locked, isInSection else { return }
        lockState = .unlocked
        announce(PhotoText.unlocked)
        await load()
    }

    /// `.inactive` couvre ; `.background` couvre et reverrouille ; `.active` découvre et, après un reverrouillage, redemande Face ID.
    /// Plusieurs écrans de la section peuvent relayer la même phase : un second appel ne change rien.
    public func scenePhaseChanged(_ newPhase: ScenePhase) {
        phase = newPhase
        switch newPhase {
        case .active:
            isCovered = false
            if promptsOnActive {
                promptsOnActive = false
                pendingUnlock = Task { await self.unlock() }
            }
        case .background:
            isCovered = true
            if lockState == .unlocked && isLockEnabled {
                relock()
                promptsOnActive = true
            }
        default:
            isCovered = true
        }
    }

    /// À la sortie de la section : reverrouille si le verrou est actif et oublie la liste.
    public func disappear() {
        isInSection = false
        promptsOnActive = false
        pendingUnlock?.cancel()
        if lockState == .unlocked && isLockEnabled {
            relock()
        } else {
            forget()
        }
    }

    /// Un écran de la section apparaît : un reverrouillage en attente est annulé.
    public func screenAppeared() {
        visibleScreens += 1
        pendingLeave?.cancel()
        pendingLeave = nil
    }

    /// Un écran de la section disparaît. Passer de la liste à la comparaison fait disparaître l'une puis apparaître l'autre ; si
    /// aucun écran de la section ne revient avant `grace` (on a quitté la section ou changé d'onglet), elle se reverrouille.
    public func screenDisappeared(grace: Duration = .milliseconds(500)) {
        visibleScreens = max(0, visibleScreens - 1)
        guard visibleScreens == 0 else { return }
        pendingLeave?.cancel()
        pendingLeave = Task { [weak self] in
            try? await Task.sleep(for: grace)
            guard let self, !Task.isCancelled, visibleScreens == 0 else { return }
            disappear()
        }
    }

    private func relock() {
        lockState = .locked
        forget()
    }

    /// Oublie ce qui a été lu et abandonne une archive d'export restée en attente.
    private func forget() {
        days = []
        thumbnails = [:]
        if pendingExport != nil {
            pendingExport = nil
            Task { [service] in await service.discardExport() }
        }
    }

    /// Une authentification ; jamais deux à la fois. Elle échoue si l'app est passée en arrière-plan pendant la demande.
    private func authenticate() async -> Bool {
        guard let authentication, !isAuthenticating else { return false }
        isAuthenticating = true
        let succeeded = await authentication.authenticate(reason: PhotoText.unlockReason)
        isAuthenticating = false
        return succeeded && phase != .background
    }

    // MARK: Liste

    /// Lit les jours, puis les vignettes qui manquent. Chaque lecture revérifie le verrou : un reverrouillage en cours de route
    /// ne laisse rien en mémoire.
    func load() async {
        guard canReadFiles else { return }
        do {
            let loaded = try await service.days()
            guard canReadFiles else { return }
            days = loaded
            errorMessage = nil
            let ids = Set(photos.map(\.id))
            thumbnails = thumbnails.filter { ids.contains($0.key) }
            for photo in photos where thumbnails[photo.id] == nil {
                let data = try? await service.thumbnail(of: photo.id)
                guard canReadFiles else { return }
                if let data { thumbnails[photo.id] = data }
            }
        } catch {
            if canReadFiles { errorMessage = PhotoText.loadFailed }
        }
    }

    /// L'image entière (JPEG) ; `nil` tant que la section est verrouillée, ou si elle ne se lit pas (`errorMessage` le dit).
    public func image(of photoID: UUID) async -> Data? {
        guard canReadFiles else { return nil }
        do {
            let data = try await service.image(of: photoID)
            return canReadFiles ? data : nil
        } catch {
            if canReadFiles { errorMessage = PhotoText.imageUnavailable }
            return nil
        }
    }

    /// « Photo de face, 1er août 2026 ».
    public func spokenLabel(of photo: BodyPhoto) -> String {
        PhotoText.bodyPhotoLabel(pose: photo.pose, day: photo.takenAt, calendar: calendar)
    }

    /// « 28 octobre », avec l'année si ce n'est pas l'année en cours.
    public func dayTitle(_ day: BodyPhotoDay) -> String {
        PhotoText.dayTitle(day.day, now: now(), calendar: calendar)
    }

    /// « 3 photos ».
    public func photoCountText(_ day: BodyPhotoDay) -> String {
        PhotoText.photoCount(day.photos.count)
    }

    /// « Remplacer la photo de face du 28 octobre ? ».
    public func replaceTitle(_ photo: BodyPhoto) -> String {
        PhotoText.replaceTitle(pose: photo.pose, day: photo.takenAt, calendar: calendar)
    }

    public func makeCompareModel() -> BodyPhotoCompareModel {
        BodyPhotoCompareModel(service: service, photos: photos, calendar: calendar)
    }

    public func clearError() {
        errorMessage = nil
    }
}

// MARK: - Ajout, suppression et réglages

extension BodyPhotosModel {
    /// Traite l'image reçue (appareil photo ou Photos). La date proposée est celle des métadonnées, sinon maintenant (une photo
    /// prise n'en a pas), jamais dans le futur ; elle reste modifiable. `nil` si l'image ne se lit pas (`errorMessage` le dit).
    public func prepare(_ data: Data?) async -> BodyPhotoDraft? {
        guard canReadFiles else { return nil }
        errorMessage = nil
        do {
            let processed = try await service.process(data ?? Data())
            let proposed = processed.capturedAt ?? now()
            return BodyPhotoDraft(processed: processed, takenAt: min(proposed, now()))
        } catch {
            errorMessage = PhotoText.unreadableImage
            return nil
        }
    }

    /// La photo de cette pose déjà prise ce jour-là : l'enregistrement la remplacera, après confirmation.
    public func photoToReplace(pose: BodyPose, on date: Date) async -> BodyPhoto? {
        guard canReadFiles else { return nil }
        return try? await service.existing(pose: pose, on: date)
    }

    /// Enregistre la photo ; `replacing` est la photo dont l'utilisateur a confirmé le remplacement (`photoToReplace`), la seule
    /// supprimée. Une date future revient à maintenant.
    public func save(_ draft: BodyPhotoDraft, pose: BodyPose, takenAt: Date, replacing: UUID? = nil) async -> Bool {
        guard canReadFiles else { return false }
        do {
            _ = try await service.save(draft.processed, pose: pose, takenAt: min(takenAt, now()), replacing: replacing)
            announce(PhotoText.photoAdded)
            await load()
            await rescheduleReminder()
            return true
        } catch {
            errorMessage = PhotoText.addFailed
            return false
        }
    }

    public func delete(_ photoID: UUID) async -> Bool {
        guard canReadFiles else { return false }
        do {
            try await service.delete(photoID: photoID)
            thumbnails[photoID] = nil
            announce(PhotoText.photoDeleted)
            await load()
            await rescheduleReminder()
            return true
        } catch {
            errorMessage = PhotoText.deleteFailed
            return false
        }
    }

    // MARK: Réglages

    /// Activer le verrou ne demande rien ; le couper demande une authentification réussie. Sans code, rien ne change.
    public func setLockEnabled(_ on: Bool) async {
        guard hasPasscode, on != lockSetting, canReadFiles else { return }
        if !on {
            guard await authenticate() else { return }
        }
        lock.setLockEnabled(on)
        lockSetting = on
    }

    /// Écrit l'archive d'export, après une authentification si le verrou est actif ; `nil` en cas d'échec, ou si la section s'est
    /// reverrouillée (ou a été quittée) pendant l'écriture : l'archive est alors supprimée. La vue la propose au sélecteur de
    /// Fichiers, puis appelle `exportFinished`.
    public func exportArchive() async -> URL? {
        guard canReadFiles, !isExporting else { return nil }
        if isLockEnabled {
            guard await authenticate() else { return nil }
        }
        guard canReadFiles else { return nil }
        isExporting = true
        defer { isExporting = false }
        do {
            let url = try await service.exportArchive()
            guard canReadFiles, isInSection else {
                await service.discardExport()
                return nil
            }
            pendingExport = url
            return url
        } catch {
            errorMessage = PhotoText.exportFailed
            return nil
        }
    }

    /// Le sélecteur de Fichiers s'est fermé (enregistré, annulé ou en échec) : l'archive temporaire est supprimée.
    public func exportFinished(failed: Bool) async {
        pendingExport = nil
        await service.discardExport()
        if failed { errorMessage = PhotoText.exportSaveFailed }
    }

    public func deleteAll() async {
        guard canReadFiles else { return }
        do {
            try await service.deleteAll()
            days = []
            thumbnails = [:]
            errorMessage = nil
            announce(PhotoText.allDeleted)
            await rescheduleReminder()
        } catch {
            errorMessage = PhotoText.deleteAllFailed
        }
    }

    private func announce(_ text: String) {
        announcement = text
        announcementSerial += 1
    }
}
