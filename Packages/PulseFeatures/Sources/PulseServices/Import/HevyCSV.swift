import Foundation

public enum HevyImportError: Error, Equatable {
    /// Le fichier n'a pas l'en-tête d'un export Hevy.
    case notHevyExport
    /// Une date de la ligne `line` du fichier n'a pas pu être lue.
    case invalidDate(line: Int)
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
    /// Les nombres s'écrivent avec un point décimal.
    public static func rows(from data: Data, calendar: Calendar) throws -> [HevyRow] {
        guard let text = String(data: data, encoding: .utf8) else { throw HevyImportError.notHevyExport }
        let records = CSVReader.numberedRecords(text)
        guard let headerRecord = records.first else { throw HevyImportError.empty }
        let columns = Columns(headerRecord.fields)
        guard columns.isComplete else { throw HevyImportError.notHevyExport }
        guard records.count > 1 else { throw HevyImportError.empty }
        return try records.dropFirst().map { try row($0, columns: columns, calendar: calendar) }
    }

    private static func row(_ record: CSVReader.Record, columns: Columns, calendar: Calendar) throws -> HevyRow {
        let text = { (name: String) in columns.value(name, in: record.fields) }
        let optionalText = { (name: String) -> String? in text(name).isEmpty ? nil : text(name) }
        let number = { (name: String) in text(name).trimmingCharacters(in: .whitespaces) }
        let decimal = { (name: String) in Double(number(name)).flatMap { $0.isFinite ? $0 : nil } }
        guard let startedAt = HevyDate.parse(text("start_time"), calendar: calendar),
              let endedAt = HevyDate.parse(text("end_time"), calendar: calendar)
        else { throw HevyImportError.invalidDate(line: record.line) }
        return HevyRow(
            title: text("title"), startedAt: startedAt, endedAt: endedAt, description: optionalText("description"),
            exerciseTitle: text("exercise_title"), supersetID: Int(number("superset_id")),
            exerciseNotes: optionalText("exercise_notes"), setIndex: Int(number("set_index")) ?? 0, setType: text("set_type"),
            weightKg: decimal("weight_kg"), reps: Int(number("reps")), distanceKm: decimal("distance_km"),
            durationSeconds: Int(number("duration_seconds")), rpe: decimal("rpe"))
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

        /// Le champ de la colonne `name`, tel quel ; vide quand la ligne est plus courte que l'en-tête.
        func value(_ name: String, in fields: [String]) -> String {
            guard let index = indices[name], fields.indices.contains(index) else { return "" }
            return fields[index]
        }
    }
}
