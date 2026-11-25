import Foundation
import PulseDomain

/// Les photos de corps : traitement de l'image, une photo par pose et par jour local, variation de poids, export. Un acteur :
/// le traitement de l'image tourne sur son exécuteur, jamais sur l'acteur principal. Premier plan seulement (spec §6.4) :
/// aucun code d'arrière-plan ne l'appelle.
public actor BodyPhotoService {
    private let store: any BodyPhotoStore
    private let measurements: any BodyMeasurementRepository
    private let calendar: Calendar
    private let timeZone: TimeZone
    private let now: @Sendable () -> Date
    /// Le dossier de l'archive d'export : `exportDirectory` dans l'app, un dossier propre à chaque test (les tests tournent en
    /// parallèle, et l'un supprimerait le dossier d'un autre pendant qu'il écrit).
    private let archiveDirectory: URL
    /// Les enregistrements passent l'un après l'autre : « enregistrer, puis supprimer la photo du jour » se libère à chaque
    /// `await`, et deux enregistrements concurrents laisseraient deux photos de même pose et de même jour.
    private let queue = SerialTaskQueue()

    public init(store: any BodyPhotoStore, measurements: any BodyMeasurementRepository, calendar: Calendar,
                timeZone: TimeZone = .current, exportDirectory: URL = BodyPhotoService.exportDirectory,
                now: @escaping @Sendable () -> Date) {
        self.store = store
        self.measurements = measurements
        self.calendar = calendar
        self.timeZone = timeZone
        archiveDirectory = exportDirectory
        self.now = now
    }

    /// Le dossier de l'archive d'export de l'app, dans les fichiers temporaires. L'effaceur le supprime aussi.
    public static var exportDirectory: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("PulseBodyPhotoExport", isDirectory: true)
    }

    /// Les jours de prise, le plus récent d'abord, avec leurs photos par pose.
    public func days() async throws -> [BodyPhotoDay] {
        BodyPhotoTimeline.days(try await store.photos(), calendar: calendar)
    }

    public func photos() async throws -> [BodyPhoto] {
        try await store.photos()
    }

    /// La vignette de la photo (JPEG) ; `nil` si elle n'existe pas.
    public func thumbnail(of photoID: UUID) async throws -> Data? {
        try await store.image(of: photoID)?.thumbnail
    }

    /// L'image de la photo (JPEG) ; `nil` si elle n'existe pas.
    public func image(of photoID: UUID) async throws -> Data? {
        try await store.image(of: photoID)?.image
    }

    /// Redresse, réduit et nettoie l'image ; `capturedAt` propose la date de prise (aujourd'hui si `nil`, au choix de l'appelant).
    public func process(_ data: Data) async throws -> ProcessedPhoto {
        try PhotoProcessor.process(data, timeZone: timeZone)
    }

    /// La photo de cette pose prise ce jour-là, s'il y en a une.
    public func existing(pose: BodyPose, on date: Date) async throws -> BodyPhoto? {
        BodyPhotoTimeline.existing(pose: pose, on: date, in: try await store.photos(), calendar: calendar)
    }

    /// Enregistre la photo, puis supprime celle de même pose et de même jour : l'appelant a confirmé le remplacement.
    public func save(_ processed: ProcessedPhoto, pose: BodyPose, takenAt: Date) async throws -> BodyPhoto {
        try await queue.run { try await self.replacingSave(processed, pose: pose, takenAt: takenAt) }
    }

    /// La nouvelle photo d'abord : les photos de corps n'ont aucune autre copie, et une écriture qui échoue (disque plein,
    /// protection des fichiers) ne doit pas emporter l'ancienne. Les deux partagent brièvement le créneau, et la liste montre la
    /// plus récente (`BodyPhotoTimeline`). Une ancienne qui ne se supprime pas reste en trop, sans faire échouer l'ajout déjà
    /// écrit : le remplacement suivant de ce créneau la retire.
    private func replacingSave(_ processed: ProcessedPhoto, pose: BodyPose, takenAt: Date) async throws -> BodyPhoto {
        let sameSlot = try await store.photos().filter { $0.pose == pose && calendar.isDate($0.takenAt, inSameDayAs: takenAt) }
        let photo = BodyPhoto(id: UUID(), pose: pose, takenAt: takenAt, createdAt: now())
        try await store.save(photo, image: processed.image)
        for old in sameSlot {
            try? await store.delete(photoID: old.id)
        }
        return photo
    }

    public func delete(photoID: UUID) async throws {
        try await queue.run { try await self.store.delete(photoID: photoID) }
    }

    public func deleteAll() async throws {
        try await queue.run { try await self.store.deleteAll() }
    }

    /// Écrit l'archive dans le dossier d'export (le dépôt protège le zip et retire les archives précédentes). L'écran la propose
    /// au sélecteur de Fichiers, puis appelle `discardExport`.
    public func exportArchive() async throws -> URL {
        try await store.exportArchive(to: archiveDirectory)
    }

    /// Supprime le dossier de l'archive. Au mieux : un dossier absent ou déjà vidé n'est pas une erreur.
    public func discardExport() async {
        try? FileManager.default.removeItem(at: archiveDirectory)
    }

    /// Variation de la tendance du poids entre deux dates, toutes sources de pesées confondues, ou `nil` si l'une des deux n'a pas
    /// de tendance. Les pesées lues vont de 14 jours avant la première date (la tendance d'un jour moyenne les 7 jours qui le finissent,
    /// et le dernier point de tendance utile peut dater de 6 jours avant la date) à la fin du jour de la seconde.
    public func weightChange(from: Date, to: Date) async throws -> Double? {
        let start = calendar.date(byAdding: .day, value: -2 * WeightTrend.window, to: calendar.startOfDay(for: from)) ?? from
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: to)) ?? to
        let trend = WeightTrend.make(measurements: try await measurements.measurements(from: start, to: end), now: now(),
                                     calendar: calendar)
        return BodyPhotoTimeline.weightChange(trend: trend, from: from, to: to, calendar: calendar)
    }
}
