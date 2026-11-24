import Foundation
import PulseDomain

/// Les photos de corps : la donnée la plus sensible de l'app, donc ni SwiftData, ni iCloud, ni export général (spec V2b §6).
/// Tout vit dans un dossier dédié, illisible quand l'iPhone est verrouillé (protection `complete`, chaque fichier écrit
/// avec `.completeFileProtection`) et exclu des sauvegardes. Disposition : `index.json` (`[BodyPhoto]`, dates ISO 8601),
/// `<id>.jpg` et `<id>-thumb.jpg`. L'index évite de lire les dates des fichiers (pas de raison `C617.1` à déclarer).
/// À n'appeler qu'au premier plan : un fichier protégé ne se lit pas en arrière-plan, iPhone verrouillé.
public actor FileBodyPhotoStore: BodyPhotoStore {
    private static let writeOptions: Data.WritingOptions = [.atomic, .completeFileProtection]

    private let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    public func photos() async throws -> [BodyPhoto] {
        let entries = readIndex()
        let present = entries.filter { FileManager.default.fileExists(atPath: imageURL($0.id).path) }
        // Un fichier disparu (effacé à la main, restauration partielle) emporte son entrée : l'index reste le miroir du dossier.
        if present.count != entries.count {
            try writeIndex(present)
        }
        return present
    }

    public func image(of photoID: UUID) async throws -> PhotoImage? {
        guard let image = try? Data(contentsOf: imageURL(photoID)),
              let thumbnail = try? Data(contentsOf: thumbnailURL(photoID)) else { return nil }
        return PhotoImage(image: image, thumbnail: thumbnail)
    }

    public func save(_ photo: BodyPhoto, image: PhotoImage) async throws {
        try prepareDirectory()
        try image.image.write(to: imageURL(photo.id), options: Self.writeOptions)
        try image.thumbnail.write(to: thumbnailURL(photo.id), options: Self.writeOptions)
        var entries = readIndex().filter { $0.id != photo.id }
        entries.append(photo)
        try writeIndex(entries)
    }

    public func delete(photoID: UUID) async throws {
        try removeIfPresent(imageURL(photoID))
        try removeIfPresent(thumbnailURL(photoID))
        let entries = readIndex()
        let remaining = entries.filter { $0.id != photoID }
        if remaining.count != entries.count {
            try writeIndex(remaining)
        }
    }

    public func deleteAll() async throws {
        try removeIfPresent(directory)
    }

    /// `Pulse-photos-de-corps-AAAA-MM-JJ.zip` dans `directory` : les images nommées `AAAA-MM-JJ-face|profil|dos.jpg`
    /// (jour de prise de vue, fuseau de l'appareil), zippées depuis un dossier de travail supprimé ensuite.
    public func exportArchive(to directory: URL) async throws -> URL {
        let stem = "Pulse-photos-de-corps"
        let staging = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let folder = staging.appendingPathComponent(stem, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: staging) }

        var taken = Set<String>()
        let ordered = try await photos().sorted {
            ($0.takenAt, $0.createdAt, $0.id.uuidString) < ($1.takenAt, $1.createdAt, $1.id.uuidString)
        }
        for photo in ordered {
            guard let data = try? Data(contentsOf: imageURL(photo.id)) else { continue }
            let name = Self.uniqueName(for: photo, taken: taken)
            taken.insert(name)
            try data.write(to: folder.appendingPathComponent(name), options: Self.writeOptions)
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let archive = directory.appendingPathComponent("\(stem)-\(ExportNaming.dayStamp(Date(), timeZone: .current)).zip")
        try ZipArchiver.zip(directory: folder, to: archive)
        return archive
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

    /// Crée le dossier protégé s'il manque ; l'exclusion des sauvegardes est posée à chaque création.
    private func prepareDirectory() throws {
        guard !FileManager.default.fileExists(atPath: directory.path) else { return }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                                attributes: [.protectionKey: FileProtectionType.complete])
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var url = directory
        try url.setResourceValues(values)
    }

    /// Un index absent ou illisible vaut un index vide : les photos restent récupérables au pire en les réajoutant.
    private func readIndex() -> [BodyPhoto] {
        guard let data = try? Data(contentsOf: indexURL) else { return [] }
        return (try? Self.decoder.decode([BodyPhoto].self, from: data)) ?? []
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
