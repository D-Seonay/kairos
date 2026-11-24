import Foundation
import PulseDomain

/// Les photos de corps : la donnée la plus sensible de l'app, donc ni SwiftData, ni iCloud, ni export général (spec V2b §6).
/// Tout vit dans un dossier dédié, illisible quand l'iPhone est verrouillé (protection `complete`, chaque fichier écrit
/// avec `.completeFileProtection`) et exclu des sauvegardes. Disposition : `index.json` (`[BodyPhoto]`, dates ISO 8601),
/// `<id>.jpg` et `<id>-thumb.jpg`. L'index évite de lire les dates des fichiers (pas de raison `C617.1` à déclarer).
/// À n'appeler qu'au premier plan : un fichier protégé ne se lit pas en arrière-plan, iPhone verrouillé.
public actor FileBodyPhotoStore: BodyPhotoStore {
    /// L'index existe mais ne se lit pas (iPhone verrouillé, fichier abîmé) : aucune écriture, sinon l'index réécrit sans les
    /// photos existantes les ferait balayer comme orphelines. « Tout supprimer » reste possible.
    public struct UnreadableIndexError: Error {}

    /// Préfixe des dossiers de travail de l'export ; ce ne sont jamais des photos, le balayage les ignore.
    private static let stagingPrefix = ".export-"
    private static let writeOptions: Data.WritingOptions = [.atomic, .completeFileProtection]

    private let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    public func photos() async throws -> [BodyPhoto] {
        let state = readIndex()
        // Index illisible (iPhone verrouillé, fichier abîmé) : rien n'est ni rendu ni nettoyé, sinon un échec de lecture
        // passager viderait le dossier.
        if case .unreadable = state { return [] }
        let entries = state.entries
        let present = entries.filter { FileManager.default.fileExists(atPath: imageURL($0.id).path) }
        // Un fichier disparu (effacé à la main, restauration partielle) emporte son entrée : l'index reste le miroir du dossier.
        if present.count != entries.count {
            try writeIndex(present)
            let kept = Set(present.map(\.id))
            for gone in entries where !kept.contains(gone.id) {
                try? removeIfPresent(thumbnailURL(gone.id))
            }
        }
        sweepOrphans(keeping: Set(present.map(\.id)))
        return present
    }

    public func image(of photoID: UUID) async throws -> PhotoImage? {
        guard let image = try? Data(contentsOf: imageURL(photoID)),
              let thumbnail = try? Data(contentsOf: thumbnailURL(photoID)) else { return nil }
        return PhotoImage(image: image, thumbnail: thumbnail)
    }

    public func save(_ photo: BodyPhoto, image: PhotoImage) async throws {
        var entries = try writableEntries()
        try prepareDirectory()
        let isNew = !entries.contains { $0.id == photo.id }
        do {
            try image.image.write(to: imageURL(photo.id), options: Self.writeOptions)
            try image.thumbnail.write(to: thumbnailURL(photo.id), options: Self.writeOptions)
            entries.removeAll { $0.id == photo.id }
            entries.append(photo)
            try writeIndex(entries)
        } catch {
            // Une photo neuve qui n'a pas pu entrer dans l'index ne laisse pas de fichiers sans entrée.
            if isNew {
                try? removeIfPresent(imageURL(photo.id))
                try? removeIfPresent(thumbnailURL(photo.id))
            }
            throw error
        }
    }

    public func delete(photoID: UUID) async throws {
        // L'index d'abord : si une suppression de fichier échoue, il reste un fichier sans entrée, que `photos()` balaie.
        let entries = try writableEntries()
        let remaining = entries.filter { $0.id != photoID }
        if remaining.count != entries.count {
            try writeIndex(remaining)
        }
        let imageError = Result { try removeIfPresent(imageURL(photoID)) }
        let thumbnailError = Result { try removeIfPresent(thumbnailURL(photoID)) }
        try imageError.get()
        try thumbnailError.get()
    }

    public func deleteAll() async throws {
        try removeIfPresent(directory)
    }

    /// `Pulse-photos-de-corps-AAAA-MM-JJ.zip` dans `destination` : les images nommées `AAAA-MM-JJ-face|profil|dos.jpg`
    /// (jour de prise de vue, fuseau de l'appareil). Le dossier de travail est dans le dossier protégé, supprimé ensuite ;
    /// l'archive reçoit la protection complète, et une archive d'un export précédent est supprimée avant d'écrire.
    public func exportArchive(to destination: URL) async throws -> URL {
        let ordered = try await photos().sorted {
            ($0.takenAt, $0.createdAt, $0.id.uuidString) < ($1.takenAt, $1.createdAt, $1.id.uuidString)
        }
        try prepareDirectory()
        let stem = "Pulse-photos-de-corps"
        let staging = directory.appendingPathComponent("\(Self.stagingPrefix)\(UUID().uuidString)", isDirectory: true)
        let folder = staging.appendingPathComponent(stem, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: staging) }

        var taken = Set<String>()
        for photo in ordered {
            // L'archive est la seule copie des photos de corps : une image illisible fait échouer l'export, jamais une archive partielle.
            let data = try Data(contentsOf: imageURL(photo.id))
            let name = Self.uniqueName(for: photo, taken: taken)
            taken.insert(name)
            try data.write(to: folder.appendingPathComponent(name), options: Self.writeOptions)
        }
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        removePreviousArchives(in: destination, stem: stem)
        let archive = destination.appendingPathComponent("\(stem)-\(ExportNaming.dayStamp(Date(), timeZone: .current)).zip")
        try ZipArchiver.zip(directory: folder, to: archive)
        try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: archive.path)
        return archive
    }

    private func removePreviousArchives(in destination: URL, stem: String) {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: destination.path)) ?? []
        for name in names where name.hasPrefix("\(stem)-") && name.hasSuffix(".zip") {
            try? FileManager.default.removeItem(at: destination.appendingPathComponent(name))
        }
    }

    // MARK: - Noms d'export

    /// `AAAA-MM-JJ-face.jpg` ; une deuxième photo du même jour et de la même pose reçoit `-2`, puis `-3`…
    private static func uniqueName(for photo: BodyPhoto, taken: Set<String>) -> String {
        let stem = "\(ExportNaming.dayStamp(photo.takenAt, timeZone: .current))-\(poseWord(photo.pose))"
        var name = "\(stem).jpg"
        var copy = 2
        while taken.contains(name) {
            name = "\(stem)-\(copy).jpg"
            copy += 1
        }
        return name
    }

    private static func poseWord(_ pose: BodyPose) -> String {
        switch pose {
        case .front: "face"
        case .side: "profil"
        case .back: "dos"
        }
    }

    // MARK: - Fichiers

    private var indexURL: URL { directory.appendingPathComponent("index.json") }
    private func imageURL(_ id: UUID) -> URL { directory.appendingPathComponent("\(id.uuidString).jpg") }
    private func thumbnailURL(_ id: UUID) -> URL { directory.appendingPathComponent("\(id.uuidString)-thumb.jpg") }

    /// Crée le dossier protégé s'il manque, et pose l'exclusion des sauvegardes à chaque appel : un dossier créé par un autre
    /// chemin (restauration, ancienne version) la reçoit aussi.
    private func prepareDirectory() throws {
        if !FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                                    attributes: [.protectionKey: FileProtectionType.complete])
        }
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var url = directory
        try url.setResourceValues(values)
    }

    private enum IndexState {
        case absent
        case decoded([BodyPhoto])
        case unreadable

        /// Un index absent ou illisible n'a aucune entrée ; les écritures refusent l'index illisible (`writableEntries`).
        var entries: [BodyPhoto] {
            if case .decoded(let entries) = self { entries } else { [] }
        }
    }

    /// Les entrées de l'index avant une écriture ; jette `UnreadableIndexError` si l'index existe sans se lire.
    private func writableEntries() throws -> [BodyPhoto] {
        let state = readIndex()
        if case .unreadable = state { throw UnreadableIndexError() }
        return state.entries
    }

    private func readIndex() -> IndexState {
        guard FileManager.default.fileExists(atPath: indexURL.path) else { return .absent }
        guard let data = try? Data(contentsOf: indexURL),
              let entries = try? Self.decoder.decode([BodyPhoto].self, from: data) else { return .unreadable }
        return .decoded(entries)
    }

    /// Supprime les `<id>.jpg` et `<id>-thumb.jpg` dont l'identifiant n'est pas dans l'index. Seulement quand l'index a été
    /// lu (ou n'existe pas) : jamais après un échec de lecture. Les dossiers de travail et les autres fichiers sont laissés.
    private func sweepOrphans(keeping kept: Set<UUID>) {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        for name in names where name.hasSuffix(".jpg") {
            var stem = String(name.dropLast(".jpg".count))
            if stem.hasSuffix("-thumb") { stem = String(stem.dropLast("-thumb".count)) }
            guard let id = UUID(uuidString: stem), !kept.contains(id) else { continue }
            try? FileManager.default.removeItem(at: directory.appendingPathComponent(name))
        }
    }

    private func writeIndex(_ entries: [BodyPhoto]) throws {
        try prepareDirectory()
        try Self.encoder.encode(entries).write(to: indexURL, options: Self.writeOptions)
    }

    private func removeIfPresent(_ url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
