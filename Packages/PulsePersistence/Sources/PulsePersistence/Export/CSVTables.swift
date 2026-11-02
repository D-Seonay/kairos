import Foundation
import PulseDomain

/// Une table CSV : en-tête et lignes.
public struct CSVTable: Equatable, Sendable {
    public var header: [String]
    public var rows: [[String?]]
}

/// Une colonne : nom snake_case et extraction de la valeur d'un élément.
struct CSVColumn<T>: Sendable {
    let name: String
    let value: @Sendable (T, CSVFormat) -> String?
}

/// Formats partagés par toutes les colonnes : dates ISO 8601 avec décalage, nombres avec point.
/// Le formateur n'est plus modifié après l'init, d'où `@unchecked Sendable`.
struct CSVFormat: @unchecked Sendable {
    private let dates: ISO8601DateFormatter

    init(timeZone: TimeZone) {
        dates = ISO8601DateFormatter()
        dates.formatOptions = [.withInternetDateTime]
        dates.timeZone = timeZone
    }

    func date(_ value: Date?) -> String? { value.map { dates.string(from: $0) } }
    func uuid(_ value: UUID?) -> String? { value?.uuidString }
    /// Sans « .0 » inutile : 80, 2.5, 1.25.
    func num(_ value: Double?) -> String? { value.map(Self.plain) }
    func int(_ value: Int?) -> String? { value.map { String($0) } }
    func bool(_ value: Bool) -> String { value ? "true" : "false" }
    func raw<E: RawRepresentable>(_ value: E?) -> String? where E.RawValue == String { value?.rawValue }
    func list<E: RawRepresentable>(_ values: [E]) -> String where E.RawValue == String { values.map(\.rawValue).joined(separator: "|") }
    func doubles(_ values: [Double]) -> String { values.map(Self.plain).joined(separator: "|") }

    private static func plain(_ value: Double) -> String {
        value == value.rounded() && abs(value) < 1e15 ? String(Int(value)) : String(value)
    }

    func json<E: Encodable>(_ value: E) -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(dates.string(from: date))
        }
        return (try? encoder.encode(value)).flatMap { String(bytes: $0, encoding: .utf8) }
    }

    func calibration(_ state: CalibrationState) -> String {
        switch state {
        case .ready: "ready"
        case .calibrating(let nights): "calibrating:\(nights)"
        }
    }
}

/// Les 15 tables de l'export CSV (spec M2 §6.2).
public enum CSVTables {
    public static func tables(from document: ExportDocument, timeZone: TimeZone) -> [StoreTable: CSVTable] {
        let format = CSVFormat(timeZone: timeZone)
        let days = document.programs.flatMap { program in program.days.map { (program.id, $0) } }
        let exercises = days.flatMap { _, day in day.exercises.map { (day.id, $0) } }
        let sets = document.workoutSessions.flatMap { session in session.sets.map { (session.id, $0) } }
        return [
            .profile: table(document.profile.map { [$0] } ?? [], CSVColumns.profile, format),
            .programs: table(document.programs, CSVColumns.programs, format),
            .routineDays: table(days, CSVColumns.routineDays, format),
            .routineExercises: table(exercises, CSVColumns.routineExercises, format),
            .userExercises: table(document.userExercises, CSVColumns.userExercises, format),
            .exerciseSettings: table(document.exerciseSettings, CSVColumns.exerciseSettings, format),
            .workoutSessions: table(document.workoutSessions, CSVColumns.workoutSessions, format),
            .workoutSets: table(sets, CSVColumns.workoutSets, format),
            .scheduledDays: table(document.scheduledDays, CSVColumns.scheduledDays, format),
            .dailyRecoveries: table(document.dailyRecoveries, CSVColumns.dailyRecoveries, format),
            .checkIns: table(document.checkIns, CSVColumns.checkIns, format),
            .supplements: table(document.supplements, CSVColumns.supplements, format),
            .supplementIntakes: table(document.supplementIntakes, CSVColumns.supplementIntakes, format),
            .bodyMeasurements: table(document.bodyMeasurements, CSVColumns.bodyMeasurements, format),
            .personalRecords: table(document.personalRecords, CSVColumns.personalRecords, format)
        ]
    }

    /// Une ligne par fichier : contenu, unités, version.
    public static func readme(for document: ExportDocument) -> String {
        var lines = [
            "Export Pulse \(document.appVersion), format \(document.format) v\(document.formatVersion), schéma \(document.schemaVersion),",
            "contenu \(document.contentVersion), exporté le \(ISO8601DateFormatter().string(from: document.exportedAt)).",
            "Unités : poids en kg, distances en m, durées en minutes, repos en secondes. Dates ISO 8601 avec décalage horaire.",
            "Listes jointes par | ; structures en JSON dans la cellule ; cellule vide = absent.",
            ""
        ]
        lines += StoreTable.exported.map { "\($0.fileName).csv : \(description(of: $0))" }
        return lines.joined(separator: "\n") + "\n"
    }

    private static func table<T>(_ items: [T], _ columns: [CSVColumn<T>], _ format: CSVFormat) -> CSVTable {
        CSVTable(header: columns.map(\.name), rows: items.map { item in columns.map { $0.value(item, format) } })
    }

    private static let descriptions: [StoreTable: String] = [
        .profile: "profil et préférences", .programs: "programmes de l'utilisateur", .routineDays: "jours de chaque programme",
        .routineExercises: "exercices de chaque jour", .userExercises: "exercices créés par l'utilisateur",
        .exerciseSettings: "réglages par exercice (incrément, échauffement)",
        .workoutSessions: "séances (musculation Pulse, courses et vélos importés)", .workoutSets: "séries de chaque séance",
        .scheduledDays: "semaine datée : séances placées, déplacées, validées", .dailyRecoveries: "score de récupération par jour",
        .checkIns: "check-ins du matin", .supplements: "compléments", .supplementIntakes: "prises de compléments",
        .bodyMeasurements: "poids et masse grasse", .personalRecords: "records personnels"
    ]

    private static func description(of table: StoreTable) -> String {
        descriptions[table] ?? "table locale, non exportée"
    }
}
