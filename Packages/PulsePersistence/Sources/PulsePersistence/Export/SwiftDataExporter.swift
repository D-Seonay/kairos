import Foundation
import PulseDomain
import SwiftData

public enum ExportError: Error, Equatable {
    case notImplemented
}

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

    public func exportCSVArchive() async throws -> URL {
        throw ExportError.notImplemented
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
