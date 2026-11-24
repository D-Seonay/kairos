/// Les tables du magasin, dans l'ordre de l'export. Les cinq dernières sont locales, jamais exportées.
public enum StoreTable: String, Sendable, CaseIterable {
    case profile
    case programs
    case routineDays
    case routineExercises
    case userExercises
    case exerciseSettings
    case workoutSessions
    case workoutSets
    case runTracks
    case sessionPhotos
    case scheduledDays
    case dailyRecoveries
    case checkIns
    case supplements
    case supplementIntakes
    case bodyMeasurements
    case personalRecords
    case cachedHealthSamples
    case healthQueryAnchors
    case activeSessionSnapshots
    case runDrafts
    case runHealthSummaries

    /// Nom de fichier CSV, en snake_case.
    public var fileName: String {
        rawValue.reduce(into: "") { result, character in
            if character.isUppercase {
                result.append("_")
                result.append(contentsOf: character.lowercased())
            } else {
                result.append(character)
            }
        }
    }

    /// Les tables qui entrent dans l'export JSON et CSV.
    public static var exported: [StoreTable] {
        allCases.filter {
            ![.cachedHealthSamples, .healthQueryAnchors, .activeSessionSnapshots, .runDrafts, .runHealthSummaries].contains($0)
        }
    }
}
