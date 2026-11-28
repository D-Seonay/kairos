import Foundation
import PulseDomain
import SwiftData

/// Export JSON et CSV depuis le magasin, dans un dossier temporaire vidé avant chaque export.
public struct SwiftDataExporter: DataExporter {
    public static var exportsDirectory: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("PulseExports", isDirectory: true)
    }

    private let container: ModelContainer
    private let appVersion: String
    private let contentVersion: String
    private let exerciseNames: @Sendable (String) -> String?
    private let directory: URL
    private let timeZone: TimeZone
    private let locale: String
    /// Le nombre d'images lues dans un même contexte SwiftData ; les tests le réduisent pour traverser plusieurs lots.
    var photoBatchSize = 8
    /// L'heure de l'export (README, métadonnées, nom du dossier) ; les tests la figent pour comparer deux archives.
    var now: @Sendable () -> Date = { Date() }

    public init(container: ModelContainer, appVersion: String, contentVersion: String,
                exerciseNames: @Sendable @escaping (String) -> String?, directory: URL = SwiftDataExporter.exportsDirectory,
                timeZone: TimeZone = .current, locale: String = Locale.current.identifier) {
        self.container = container
        self.appVersion = appVersion
        self.contentVersion = contentVersion
        self.exerciseNames = exerciseNames
        self.directory = directory
        self.timeZone = timeZone
        self.locale = locale
    }

    public func exportJSON() async throws -> URL {
        let snapshot = try await ExportSnapshotLoader(modelContainer: container).snapshot()
        let now = now()
        let metadata = ExportMetadata(appVersion: appVersion, contentVersion: contentVersion, locale: locale, exportedAt: now)
        let document = JSONExportWriter.document(from: snapshot, metadata: metadata, exerciseNames: exerciseNames)
        try resetDirectory()
        return try JSONExportWriter.write(document, to: directory, date: now, timeZone: timeZone)
    }

    /// Dossier `Pulse-AAAA-MM-JJ-csv/` avec un CSV par table, `README.txt` et les photos de séance dans `photos/`, zippé à côté.
    /// Le JSON ne contient aucune image : seule cette archive les porte.
    public func exportCSVArchive() async throws -> URL {
        let snapshot = try await ExportSnapshotLoader(modelContainer: container).snapshot()
        let now = now()
        let metadata = ExportMetadata(appVersion: appVersion, contentVersion: contentVersion, locale: locale, exportedAt: now)
        var document = JSONExportWriter.document(from: snapshot, metadata: metadata, exerciseNames: exerciseNames)
        try resetDirectory()
        let stem = "Pulse-\(ExportNaming.dayStamp(now, timeZone: timeZone))-csv"
        let folder = directory.appendingPathComponent(stem, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        // Seules les photos dont l'image est là ont une ligne : la colonne `file` désigne toujours un fichier de l'archive.
        let photoFiles = try await writePhotos(document.sessionPhotos, to: folder)
        document.sessionPhotos = document.sessionPhotos.filter { photoFiles[$0.id] != nil }
        for (table, csv) in CSVTables.tables(from: document, timeZone: timeZone, photoFiles: photoFiles) {
            try CSVWriter.file(header: csv.header, rows: csv.rows)
                .write(to: folder.appendingPathComponent(table.fileName + ".csv"), atomically: true, encoding: .utf8)
        }
        try CSVTables.readme(for: document).write(to: folder.appendingPathComponent("README.txt"), atomically: true, encoding: .utf8)
        let zip = directory.appendingPathComponent(stem + ".zip")
        try ZipArchiver.zip(directory: folder, to: zip)
        return zip
    }

    /// Copie chaque image vivante, octet pour octet, dans `photos/` ; rend le chemin écrit de chaque photo (identifiant -> chemin
    /// relatif). Deux photos d'une séance peuvent avoir le même rang le même jour (deux appareils) : la seconde reçoit les
    /// premiers caractères de son identifiant avant `.jpg`, jamais d'écrasement. Le dossier n'existe que s'il y a une image.
    /// Les images sont lues par lots de `photoBatchSize`, chaque lot dans un contexte neuf relâché à la fin du lot : les lignes
    /// lues et leurs images ne s'accumulent pas dans un même contexte, quel que soit le nombre de photos.
    private func writePhotos(_ photos: [SessionPhoto], to folder: URL) async throws -> [UUID: String] {
        let photosFolder = folder.appendingPathComponent("photos", isDirectory: true)
        var files: [UUID: String] = [:]
        var taken = Set<String>()
        for start in stride(from: 0, to: photos.count, by: max(1, photoBatchSize)) {
            let batch = photos[start..<min(start + max(1, photoBatchSize), photos.count)]
            let loader = ExportSnapshotLoader(modelContainer: container)
            for photo in batch {
                guard let data = try await loader.imageData(ofPhoto: photo.id) else { continue }
                let path = ExportNaming.uniquePhotoPath(photo, timeZone: timeZone, taken: taken)
                taken.insert(path)
                try FileManager.default.createDirectory(at: photosFolder, withIntermediateDirectories: true)
                try data.write(to: folder.appendingPathComponent(path), options: .atomic)
                files[photo.id] = path
            }
        }
        return files
    }

    /// Le dossier CSV du dernier export, s'il existe encore (tests et inspection).
    public func lastCSVDirectory(in directory: URL) -> URL? {
        // swiftlint:disable:next silent_try - tests et inspection : dossier absent, aucun export
        let entries = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        return entries.first { $0.hasDirectoryPath && $0.lastPathComponent.hasSuffix("-csv") }
    }

    /// Vide puis recrée le dossier d'export.
    func resetDirectory() throws {
        let manager = FileManager.default
        if manager.fileExists(atPath: directory.path) {
            try manager.removeItem(at: directory)
        }
        try manager.createDirectory(at: directory, withIntermediateDirectories: true)
    }
}
