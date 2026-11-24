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
        let now = Date()
        let metadata = ExportMetadata(appVersion: appVersion, contentVersion: contentVersion, locale: locale, exportedAt: now)
        let document = JSONExportWriter.document(from: snapshot, metadata: metadata, exerciseNames: exerciseNames)
        try resetDirectory()
        return try JSONExportWriter.write(document, to: directory, date: now, timeZone: timeZone)
    }

    /// Dossier `Pulse-AAAA-MM-JJ-csv/` avec un CSV par table, `README.txt` et les photos de séance dans `photos/`, zippé à côté.
    /// Le JSON ne contient aucune image : seule cette archive les porte.
    public func exportCSVArchive() async throws -> URL {
        let snapshot = try await ExportSnapshotLoader(modelContainer: container).snapshot()
        let now = Date()
        let metadata = ExportMetadata(appVersion: appVersion, contentVersion: contentVersion, locale: locale, exportedAt: now)
        var document = JSONExportWriter.document(from: snapshot, metadata: metadata, exerciseNames: exerciseNames)
        try resetDirectory()
        let stem = "Pulse-\(ExportNaming.dayStamp(now, timeZone: timeZone))-csv"
        let folder = directory.appendingPathComponent(stem, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        // Seules les photos dont l'image est là ont une ligne : la colonne `file` désigne toujours un fichier de l'archive.
        document.sessionPhotos = try await writePhotos(document.sessionPhotos, to: folder)
        for (table, csv) in CSVTables.tables(from: document, timeZone: timeZone) {
            try CSVWriter.file(header: csv.header, rows: csv.rows)
                .write(to: folder.appendingPathComponent(table.fileName + ".csv"), atomically: true, encoding: .utf8)
        }
        try CSVTables.readme(for: document).write(to: folder.appendingPathComponent("README.txt"), atomically: true, encoding: .utf8)
        let zip = directory.appendingPathComponent(stem + ".zip")
        try ZipArchiver.zip(directory: folder, to: zip)
        return zip
    }

    /// Copie chaque image vivante, octet pour octet, dans `photos/` ; rend les photos écrites. Le dossier n'existe que s'il y en a.
    private func writePhotos(_ photos: [SessionPhoto], to folder: URL) async throws -> [SessionPhoto] {
        let loader = ExportSnapshotLoader(modelContainer: container)
        let photosFolder = folder.appendingPathComponent("photos", isDirectory: true)
        var written: [SessionPhoto] = []
        for photo in photos {
            guard let data = try await loader.imageData(ofPhoto: photo.id) else { continue }
            try FileManager.default.createDirectory(at: photosFolder, withIntermediateDirectories: true)
            try data.write(to: folder.appendingPathComponent(ExportNaming.photoPath(photo, timeZone: timeZone)), options: .atomic)
            written.append(photo)
        }
        return written
    }

    /// Le dossier CSV du dernier export, s'il existe encore (tests et inspection).
    public func lastCSVDirectory(in directory: URL) -> URL? {
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
