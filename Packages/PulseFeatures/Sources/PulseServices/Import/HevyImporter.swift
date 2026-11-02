import Foundation
import PulseContent
import PulseDomain

public struct HevyImportResult: Sendable, Equatable {
    public let importedSessions: Int
    public let createdExercises: Int
    /// Le nombre de records après le recalcul qui clôt l'import.
    public let records: Int
    /// Les séances nouvelles qui ne gardaient aucune série : tous leurs exercices ignorés, ou des lignes toutes vides.
    public let skippedSessions: Int
    /// Les séances de cardio seul de l'aperçu, laissées de côté.
    public let cardioOnlySessions: Int

    public init(importedSessions: Int, createdExercises: Int, records: Int, skippedSessions: Int = 0, cardioOnlySessions: Int = 0) {
        self.importedSessions = importedSessions
        self.createdExercises = createdExercises
        self.records = records
        self.skippedSessions = skippedSessions
        self.cardioOnlySessions = cardioOnlySessions
    }
}

/// Importe l'historique Hevy (spec M4 §13) : lit l'export, crée les exercices perso choisis, enregistre les séances nouvelles,
/// retient les choix de correspondance pour l'import suivant et recalcule les records. Un import interrompu se reprend sans
/// doublon : la règle de doublon est revérifiée en base avant chaque séance. Les imports et les suppressions passent l'un après
/// l'autre par la même file.
public final class HevyImporter: Sendable {
    private let workouts: any WorkoutRepository
    private let userExercises: any UserExerciseRepository
    private let records: RecordsService
    private let mappings: any HevyMappingStore
    private let library: ContentLibrary
    private let calendar: Calendar
    private let now: @Sendable () -> Date
    private let queue = SerialTaskQueue()

    public init(workouts: any WorkoutRepository, userExercises: any UserExerciseRepository, records: RecordsService,
                mappings: any HevyMappingStore, library: ContentLibrary, calendar: Calendar, now: @escaping @Sendable () -> Date) {
        self.workouts = workouts
        self.userExercises = userExercises
        self.records = records
        self.mappings = mappings
        self.library = library
        self.calendar = calendar
        self.now = now
    }

    /// Ce que l'import de `data` ferait, compte tenu des séances déjà en base, des exercices perso et des choix retenus.
    public func preview(_ data: Data) async throws -> HevyImportPreview {
        let rows = try HevyCSV.rows(from: data, calendar: calendar)
        let existing = try await workouts.sessions(from: .distantPast, to: .distantFuture)
        return try HevyImportPlanner.preview(rows: rows, existing: existing, library: library,
                                             userExercises: try await userExercises.all(includeArchived: true),
                                             remembered: mappings.load())
    }

    /// Importe les séances nouvelles de `preview`, dans l'ordre. Seuls les noms de l'aperçu comptent ; un nom absent de `choices`
    /// n'est pas importé. `progress` reçoit la part des séances traitées, après chacune.
    public func run(_ preview: HevyImportPreview, choices: [String: HevyMappingChoice],
                    progress: @escaping @Sendable (Double) -> Void) async throws -> HevyImportResult {
        try await queue.run { try await self.importing(preview, choices: choices, progress: progress) }
    }

    /// Supprime toutes les séances importées de Hevy puis recalcule les records. Rend le nombre de séances supprimées.
    public func removeImportedSessions() async throws -> Int {
        try await queue.run {
            let imported = try await self.workouts.sessions(from: .distantPast, to: .distantFuture).filter { $0.source == .hevy }
            for session in imported {
                try await self.workouts.delete(id: session.id)
            }
            _ = try await self.records.recomputeAll()
            return imported.count
        }
    }

    // MARK: - Interne

    private func importing(_ preview: HevyImportPreview, choices: [String: HevyMappingChoice],
                           progress: @Sendable (Double) -> Void) async throws -> HevyImportResult {
        let now = now()
        let resolution = try await resolve(preview, choices: choices, now: now)
        let directory = ExerciseDirectory(library: library, userExercises: try await userExercises.all(includeArchived: true))
        let references = resolution.choices.compactMapValues(\.reference)
        var (imported, skipped) = (0, 0)
        for (index, workout) in preview.newWorkouts.enumerated() {
            if try await !isSaved(workout) {
                if let session = HevySessionBuilder.session(from: workout, references: references, directory: directory, now: now) {
                    try await workouts.save(session)
                    imported += 1
                } else {
                    skipped += 1
                }
            }
            progress(Double(index + 1) / Double(preview.newWorkouts.count))
        }
        return HevyImportResult(importedSessions: imported, createdExercises: resolution.created,
                                records: try await records.recomputeAll(), skippedSessions: skipped,
                                cardioOnlySessions: preview.cardioOnlyWorkoutCount)
    }

    /// Crée un exercice perso pour chaque `.create` et rend les choix des noms de l'aperçu, les créations devenues `.user`.
    /// Un exercice déjà là est repris plutôt que recréé (aperçu relancé, reprise après une erreur). Chaque création est retenue
    /// aussitôt, pour qu'une reprise ne recrée pas l'exercice ; puis tous les choix le sont.
    private func resolve(_ preview: HevyImportPreview, choices: [String: HevyMappingChoice],
                         now: Date) async throws -> (choices: [String: HevyMappingChoice], created: Int) {
        var remembered = mappings.load()
        var existing = try await userExercises.all(includeArchived: true)
        var resolved: [String: HevyMappingChoice] = [:]
        var created = 0
        for summary in preview.names {
            guard var choice = choices[summary.name] else { continue }
            if case .create(let draft) = choice {
                if let id = Self.existingExercise(for: summary.name, draft: draft, remembered: remembered, in: existing) {
                    choice = .user(id: id)
                } else {
                    let exercise = draft.userExercise(id: UUID(), now: now)
                    try await userExercises.save(exercise)
                    existing.append(exercise)
                    choice = .user(id: exercise.id)
                    created += 1
                }
                remembered[summary.name] = choice
                mappings.save(remembered)
            }
            resolved[summary.name] = choice
        }
        mappings.save(remembered.merging(resolved) { _, chosen in chosen })
        return (resolved, created)
    }

    /// L'exercice perso qui tient déjà lieu de la création : celui retenu pour le nom s'il existe encore, sinon un exercice non
    /// archivé dont le nom replié est celui du brouillon (la règle de l'aperçu).
    private static func existingExercise(for name: String, draft: UserExerciseDraft, remembered: [String: HevyMappingChoice],
                                         in exercises: [UserExercise]) -> UUID? {
        if case .user(let id) = remembered[name], exercises.contains(where: { $0.id == id }) { return id }
        let folded = SearchText.fold(draft.name)
        return exercises.first { !$0.isArchived && SearchText.fold($0.name) == folded }?.id
    }

    /// Vrai quand la séance est déjà en base : source Hevy, même titre, début dans la même minute.
    private func isSaved(_ workout: HevyWorkout) async throws -> Bool {
        let minute = HevyImportPlanner.startMinute(of: workout)
        return try await workouts.sessions(from: minute.lowerBound, to: minute.upperBound)
            .contains { HevyImportPlanner.isImport($0, of: workout) }
    }
}

private extension HevyMappingChoice {
    /// L'exercice Pulse désigné ; `nil` pour un nom ignoré ou un exercice pas encore créé.
    var reference: ExerciseReference? {
        switch self {
        case .content(let id): .content(id: id)
        case .user(let id): .user(id: id)
        case .create, .ignore: nil
        }
    }
}
