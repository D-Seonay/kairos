import Foundation

/// Unités de l'export, rappelées en tête de fichier.
public struct ExportUnits: Sendable, Equatable, Codable {
    public var weight = "kg"
    public var distance = "m"
    public var duration = "minutes"
    public var rest = "seconds"

    public init() {}
}

/// Le fichier JSON d'export entier (spec M2 §6.1). Les champs reprennent exactement ceux des entités.
public struct ExportDocument: Sendable, Equatable, Codable {
    public var format = "pulse-export"
    public var formatVersion = 1
    public var schemaVersion: Int
    public var contentVersion: String
    public var appVersion: String
    public var exportedAt: Date
    public var locale: String
    public var units = ExportUnits()
    public var profile: UserProfile?
    public var programs: [Program]
    public var userExercises: [UserExercise]
    public var exerciseSettings: [ExerciseSettings]
    public var workoutSessions: [WorkoutSession]
    public var scheduledDays: [ScheduledDay]
    public var dailyRecoveries: [DailyRecovery]
    public var checkIns: [CheckIn]
    public var supplements: [Supplement]
    public var supplementIntakes: [SupplementIntake]
    public var bodyMeasurements: [BodyMeasurement]
    public var personalRecords: [PersonalRecord]
    /// Nom français de chaque exercice du contenu référencé, pour lire le fichier sans le bundle.
    public var contentExercises: [String: String]

    public init(schemaVersion: Int, contentVersion: String, appVersion: String, exportedAt: Date, locale: String,
                profile: UserProfile?, programs: [Program], userExercises: [UserExercise],
                exerciseSettings: [ExerciseSettings] = [], workoutSessions: [WorkoutSession],
                scheduledDays: [ScheduledDay], dailyRecoveries: [DailyRecovery], checkIns: [CheckIn], supplements: [Supplement],
                supplementIntakes: [SupplementIntake], bodyMeasurements: [BodyMeasurement], personalRecords: [PersonalRecord],
                contentExercises: [String: String]) {
        self.schemaVersion = schemaVersion
        self.contentVersion = contentVersion
        self.appVersion = appVersion
        self.exportedAt = exportedAt
        self.locale = locale
        self.profile = profile
        self.programs = programs
        self.userExercises = userExercises
        self.exerciseSettings = exerciseSettings
        self.workoutSessions = workoutSessions
        self.scheduledDays = scheduledDays
        self.dailyRecoveries = dailyRecoveries
        self.checkIns = checkIns
        self.supplements = supplements
        self.supplementIntakes = supplementIntakes
        self.bodyMeasurements = bodyMeasurements
        self.personalRecords = personalRecords
        self.contentExercises = contentExercises
    }

    /// Un document sans aucune donnée.
    public static func empty(exportedAt: Date, appVersion: String, schemaVersion: Int, contentVersion: String,
                             locale: String) -> ExportDocument {
        ExportDocument(schemaVersion: schemaVersion, contentVersion: contentVersion, appVersion: appVersion, exportedAt: exportedAt,
                       locale: locale, profile: nil, programs: [], userExercises: [], exerciseSettings: [], workoutSessions: [],
                       scheduledDays: [], dailyRecoveries: [], checkIns: [], supplements: [], supplementIntakes: [],
                       bodyMeasurements: [], personalRecords: [], contentExercises: [:])
    }
}

/// Enveloppe un formateur ISO 8601 que l'init configure puis ne modifie plus, d'où `@unchecked Sendable`.
private struct ISODateFormatter: @unchecked Sendable {
    private let formatter: ISO8601DateFormatter

    init(timeZone: TimeZone? = nil) {
        formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        if let timeZone { formatter.timeZone = timeZone }
    }

    func string(from date: Date) -> String { formatter.string(from: date) }
    func date(from text: String) -> Date? { formatter.date(from: text) }
}

/// Encodage et décodage de l'export : clés triées, indenté, dates ISO 8601 avec décalage horaire.
public enum ExportCoding {
    public static func encoder(timeZone: TimeZone = .current) -> JSONEncoder {
        let formatter = ISODateFormatter(timeZone: timeZone)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(formatter.string(from: date))
        }
        return encoder
    }

    public static func decoder() -> JSONDecoder {
        let formatter = ISODateFormatter()
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let text = try container.decode(String.self)
            guard let date = formatter.date(from: text) else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Date ISO 8601 attendue : \(text)")
            }
            return date
        }
        return decoder
    }
}
