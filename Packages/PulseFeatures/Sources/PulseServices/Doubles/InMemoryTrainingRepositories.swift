import Foundation
import PulseDomain
import Synchronization

/// Doublures en mémoire des dépôts d'entraînement de SwiftData : exercices de l'utilisateur, réglages par exercice et records.

/// `save` remplace l'exercice du même `id` ; `delete` est logique et `all` trie par date de création puis par nom.
public actor InMemoryUserExerciseRepository: UserExerciseRepository {
    private var stored: [UUID: UserExercise] = [:]

    public init() {}

    public func all(includeArchived: Bool) async throws -> [UserExercise] {
        stored.values
            .filter { includeArchived || !$0.isArchived }
            .sorted { lhs, rhs in lhs.createdAt != rhs.createdAt ? lhs.createdAt < rhs.createdAt : lhs.name < rhs.name }
    }

    public func save(_ exercise: UserExercise) async throws {
        stored[exercise.id] = exercise
    }

    public func delete(id: UUID) async throws {
        stored[id] = nil
    }
}

/// Un seul enregistrement actif par exercice : `save` met à jour celui qui existe et garde son `id`.
public actor InMemoryExerciseSettingsRepository: ExerciseSettingsRepository {
    private var stored: [ExerciseReference: ExerciseSettings] = [:]

    public init() {}

    public func all() async throws -> [ExerciseSettings] {
        stored.values.sorted { lhs, rhs in
            lhs.createdAt != rhs.createdAt ? lhs.createdAt < rhs.createdAt : lhs.id.uuidString < rhs.id.uuidString
        }
    }

    public func settings(for exercise: ExerciseReference) async throws -> ExerciseSettings? {
        stored[exercise]
    }

    public func save(_ settings: ExerciseSettings) async throws {
        var replacement = settings
        if let existing = stored[settings.exercise] {
            replacement.id = existing.id
            replacement.createdAt = existing.createdAt
        }
        stored[settings.exercise] = replacement
    }
}

/// Les records en mémoire, du plus récent au plus ancien. `replaceAll` suit la règle du dépôt SwiftData : un record dont la clé
/// (série, type, charge) existe déjà garde son `id` et reçoit les nouvelles valeurs, les absents disparaissent, les nouveaux
/// sont ajoutés.
public actor InMemoryPersonalRecordRepository: PersonalRecordRepository {
    private var stored: [PersonalRecord] = []

    public init() {}

    public func records(for exercise: ExerciseReference?) async throws -> [PersonalRecord] {
        stored.filter { exercise == nil || $0.exercise == exercise }.sorted { $0.date > $1.date }
    }

    public func save(_ record: PersonalRecord) async throws {
        if let index = stored.firstIndex(where: { $0.id == record.id }) {
            stored[index] = record
        } else {
            stored.append(record)
        }
    }

    public func delete(id: UUID) async throws {
        stored.removeAll { $0.id == id }
    }

    public func replaceAll(with records: [PersonalRecord]) async throws {
        var unmatched = stored.sorted { $0.createdAt < $1.createdAt }
        var result: [PersonalRecord] = []
        for record in records {
            var replacement = record
            if let index = unmatched.firstIndex(where: { Self.sameKey($0, record) }) {
                let existing = unmatched.remove(at: index)
                replacement.id = existing.id
                replacement.createdAt = existing.createdAt
                if Self.holdsSameValues(existing, replacement) { replacement = existing }
            }
            result.append(replacement)
        }
        stored = result
    }

    /// Vrai si le recalcul n'apporte rien de nouveau : seule la date de mise à jour diffère.
    private static func holdsSameValues(_ existing: PersonalRecord, _ replacement: PersonalRecord) -> Bool {
        var comparable = replacement
        comparable.updatedAt = existing.updatedAt
        return comparable == existing
    }

    /// Identité d'un record d'un recalcul à l'autre : la série, le type et la charge.
    private static func sameKey(_ lhs: PersonalRecord, _ rhs: PersonalRecord) -> Bool {
        lhs.setID == rhs.setID && lhs.kind == rhs.kind && lhs.weightKg == rhs.weightKg
    }
}

/// Les choix de correspondance Hevy en mémoire, pour les tests et les aperçus.
public final class InMemoryHevyMappingStore: HevyMappingStore {
    private let stored: Mutex<[String: HevyMappingChoice]>

    public init(_ choices: [String: HevyMappingChoice] = [:]) {
        stored = Mutex(choices)
    }

    public func load() -> [String: HevyMappingChoice] {
        stored.withLock { $0 }
    }

    public func save(_ choices: [String: HevyMappingChoice]) {
        stored.withLock { $0 = choices }
    }
}
