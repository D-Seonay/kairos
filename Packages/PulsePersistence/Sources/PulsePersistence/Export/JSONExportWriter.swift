import Foundation
import PulseDomain

/// En-tête de l'export : versions, date, langue.
public struct ExportMetadata: Sendable {
    public var appVersion: String
    public var contentVersion: String
    public var locale: String
    public var exportedAt: Date

    public init(appVersion: String, contentVersion: String, locale: String, exportedAt: Date) {
        self.appVersion = appVersion
        self.contentVersion = contentVersion
        self.locale = locale
        self.exportedAt = exportedAt
    }
}

/// Construit et écrit le document JSON d'export (spec M2 §6.1).
public enum JSONExportWriter {
    public static func document(from snapshot: ExportSnapshot, metadata: ExportMetadata,
                                exerciseNames: (String) -> String?) -> ExportDocument {
        var names: [String: String] = [:]
        for id in snapshot.referencedContentExerciseIDs {
            if let name = exerciseNames(id) { names[id] = name }
        }
        return ExportDocument(schemaVersion: Int(PulseSchemaV1.versionIdentifier.major), contentVersion: metadata.contentVersion,
                              appVersion: metadata.appVersion, exportedAt: metadata.exportedAt, locale: metadata.locale,
                              profile: snapshot.profile,
                              programs: snapshot.programs, userExercises: snapshot.userExercises,
                              workoutSessions: snapshot.workoutSessions, scheduledDays: snapshot.scheduledDays,
                              dailyRecoveries: snapshot.dailyRecoveries, checkIns: snapshot.checkIns,
                              supplements: snapshot.supplements, supplementIntakes: snapshot.supplementIntakes,
                              bodyMeasurements: snapshot.bodyMeasurements, personalRecords: snapshot.personalRecords,
                              contentExercises: names)
    }

    /// Écrit `Pulse-AAAA-MM-JJ.json` dans `directory` et renvoie son URL.
    public static func write(_ document: ExportDocument, to directory: URL, date: Date, timeZone: TimeZone) throws -> URL {
        let url = directory.appendingPathComponent("Pulse-\(ExportNaming.dayStamp(date, timeZone: timeZone)).json")
        try ExportCoding.encoder(timeZone: timeZone).encode(document).write(to: url, options: .atomic)
        return url
    }
}

enum ExportNaming {
    /// `AAAA-MM-JJ` dans le fuseau donné.
    static func dayStamp(_ date: Date, timeZone: TimeZone) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}
