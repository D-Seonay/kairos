import Foundation

public enum HevyImportError: Error, Equatable {
    /// Le fichier n'a pas l'en-tête d'un export Hevy.
    case notHevyExport
    /// Une date de la ligne `line` du fichier n'a pas pu être lue.
    case invalidDate(line: Int)
    /// La ligne `line` du fichier est mal formée : nombre de champs différent de l'en-tête, nombre illisible ou négatif, guillemet
    /// jamais refermé (la ligne où commence l'enregistrement).
    case invalidRow(line: Int)
    /// Le fichier ne contient aucune série.
    case empty
}

/// Lit l'export CSV des séances de l'app Hevy.
public enum HevyCSV {
    public static let header = [
        "title", "start_time", "end_time", "description", "exercise_title", "superset_id", "exercise_notes", "set_index",
        "set_type", "weight_kg", "reps", "distance_km", "duration_seconds", "rpe"
    ]

    /// L'en-tête doit contenir toutes les colonnes de `header`, dans n'importe quel ordre ; les colonnes en plus sont ignorées.
    /// Un champ numérique vide vaut `nil` ; un champ illisible ou négatif, comme une ligne de longueur différente de l'en-tête,
    /// fait échouer la lecture. Les décimaux s'écrivent avec un point ou une virgule ; `reps`, `set_index`, `superset_id` et
    /// `duration_seconds` sont des entiers.
    public static func rows(from data: Data, calendar: Calendar) throws -> [HevyRow] {
        guard let text = String(data: data, encoding: .utf8) else { throw HevyImportError.notHevyExport }
        let parsed = CSVReader.parse(text)
        if let line = parsed.unterminatedQuoteLine { throw HevyImportError.invalidRow(line: line) }
        let records = parsed.records
        guard let headerRecord = records.first else { throw HevyImportError.empty }
        let columns = Columns(headerRecord.fields)
        guard columns.isComplete else { throw HevyImportError.notHevyExport }
        guard records.count > 1 else { throw HevyImportError.empty }
        return try records.dropFirst().map { record in
            guard record.fields.count == headerRecord.fields.count else { throw HevyImportError.invalidRow(line: record.line) }
            return try row(RecordFields(record: record, columns: columns), calendar: calendar)
        }
    }

    private static func row(_ fields: RecordFields, calendar: Calendar) throws -> HevyRow {
        guard let startedAt = HevyDate.parse(fields.text("start_time"), calendar: calendar),
              let endedAt = HevyDate.parse(fields.text("end_time"), calendar: calendar)
        else { throw HevyImportError.invalidDate(line: fields.record.line) }
        return HevyRow(
            title: fields.text("title"), startedAt: startedAt, endedAt: endedAt, description: fields.optionalText("description"),
            exerciseTitle: fields.text("exercise_title"), supersetID: try fields.integer("superset_id"),
            exerciseNotes: fields.optionalText("exercise_notes"), setIndex: try fields.integer("set_index") ?? 0,
            setType: fields.text("set_type"), weightKg: try fields.decimal("weight_kg"), reps: try fields.integer("reps"),
            distanceKm: try fields.decimal("distance_km"), durationSeconds: try fields.integer("duration_seconds"),
            rpe: try fields.decimal("rpe"))
    }

    /// Les champs d'un enregistrement, lus par nom de colonne.
    private struct RecordFields {
        let record: CSVReader.Record
        let columns: Columns

        func text(_ name: String) -> String {
            columns.value(name, in: record.fields)
        }

        func optionalText(_ name: String) -> String? {
            let value = text(name)
            return value.isEmpty ? nil : value
        }

        /// Un entier positif ou nul ; `nil` si le champ est vide.
        func integer(_ name: String) throws -> Int? {
            let value = text(name).trimmingCharacters(in: .whitespaces)
            if value.isEmpty { return nil }
            guard value.allSatisfy({ $0.isASCII && $0.isNumber }), let number = Int(value) else {
                throw HevyImportError.invalidRow(line: record.line)
            }
            return number
        }

        /// Un décimal positif ou nul, avec un point ou une virgule ; `nil` si le champ est vide.
        func decimal(_ name: String) throws -> Double? {
            let value = text(name).trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
            if value.isEmpty { return nil }
            guard value.allSatisfy({ ($0.isASCII && $0.isNumber) || $0 == "." }), let number = Double(value) else {
                throw HevyImportError.invalidRow(line: record.line)
            }
            return number
        }
    }

    private struct Columns {
        private let indices: [String: Int]

        init(_ names: [String]) {
            indices = Dictionary(names.enumerated().map { ($1.trimmingCharacters(in: .whitespaces), $0) },
                                 uniquingKeysWith: { first, _ in first })
        }

        var isComplete: Bool {
            HevyCSV.header.allSatisfy { indices[$0] != nil }
        }

        /// Le champ de la colonne `name`, tel quel ; vide si la colonne n'existe pas.
        func value(_ name: String, in fields: [String]) -> String {
            guard let index = indices[name], fields.indices.contains(index) else { return "" }
            return fields[index]
        }
    }
}
