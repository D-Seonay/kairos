import Foundation
import PulseDomain

/// Doublures en mémoire des dépôts SwiftData, avec la même sémantique observable.

public actor InMemoryProfileRepository: ProfileRepository {
    private var profiles: [UserProfile] = []
    private var deletedIDs: Set<UUID> = []

    public init() {}

    public func load() async throws -> UserProfile? {
        profiles.filter { !deletedIDs.contains($0.id) }.min { lhs, rhs in
            lhs.createdAt != rhs.createdAt ? lhs.createdAt < rhs.createdAt : lhs.id.uuidString < rhs.id.uuidString
        }
    }

    public func save(_ profile: UserProfile) async throws {
        deletedIDs.remove(profile.id)
        if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[index] = profile
        } else {
            profiles.append(profile)
        }
    }

    /// Suppression logique : le profil reste stocké mais n'est plus renvoyé.
    public func delete(id: UUID) async throws {
        if profiles.contains(where: { $0.id == id }) {
            deletedIDs.insert(id)
        }
    }
}

public actor InMemoryProgramRepository: ProgramRepository {
    private var stored: [Program] = []
    private var deletedIDs: Set<UUID> = []

    public init() {}

    public func programs(includeArchived: Bool) async throws -> [Program] {
        stored
            .filter { !deletedIDs.contains($0.id) && (includeArchived || !$0.isArchived) }
            .sorted { lhs, rhs in lhs.createdAt != rhs.createdAt ? lhs.createdAt < rhs.createdAt : lhs.name < rhs.name }
    }

    public func program(id: UUID) async throws -> Program? {
        deletedIDs.contains(id) ? nil : stored.first { $0.id == id }
    }

    /// Remplace le programme entier, jours et exercices compris.
    public func save(_ program: Program) async throws {
        deletedIDs.remove(program.id)
        if let index = stored.firstIndex(where: { $0.id == program.id }) {
            stored[index] = program
        } else {
            stored.append(program)
        }
    }

    public func delete(id: UUID) async throws {
        if stored.contains(where: { $0.id == id }) {
            deletedIDs.insert(id)
        }
    }
}

/// Un enregistrement par jour local : le jour est normalisé avec `calendar`, `save` remplace en gardant `id` et `createdAt`.
public actor InMemoryRecoveryRepository: RecoveryRepository {
    private let calendar: Calendar
    private var recoveries: [Date: DailyRecovery] = [:]
    private var checkInsByDay: [Date: CheckIn] = [:]

    public init(calendar: Calendar) {
        self.calendar = calendar
    }

    public func dailyRecoveries(from: Date, to: Date) async throws -> [DailyRecovery] {
        recoveries.values.filter { $0.day >= from && $0.day < to }.sorted { $0.day < $1.day }
    }

    public func save(_ recovery: DailyRecovery) async throws {
        var stamped = recovery
        stamped.day = calendar.startOfDay(for: recovery.day)
        if let existing = recoveries[stamped.day] {
            stamped.id = existing.id
            stamped.createdAt = existing.createdAt
        }
        recoveries[stamped.day] = stamped
    }

    public func checkIns(from: Date, to: Date) async throws -> [CheckIn] {
        checkInsByDay.values.filter { $0.day >= from && $0.day < to }.sorted { $0.day < $1.day }
    }

    public func save(_ checkIn: CheckIn) async throws {
        var stamped = checkIn
        stamped.day = calendar.startOfDay(for: checkIn.day)
        if let existing = checkInsByDay[stamped.day] {
            stamped.id = existing.id
            stamped.createdAt = existing.createdAt
        }
        checkInsByDay[stamped.day] = stamped
    }
}

/// Les séances en mémoire : `sessions(from:to:)` renvoie celles dont `startedAt` est dans `[from, to)`, de la plus ancienne
/// à la plus récente.
public actor InMemoryWorkoutRepository: WorkoutRepository {
    private var stored: [UUID: WorkoutSession] = [:]

    public init() {}

    public func sessions(from: Date, to: Date) async throws -> [WorkoutSession] {
        stored.values
            .filter { $0.startedAt >= from && $0.startedAt < to }
            .sorted { lhs, rhs in lhs.startedAt != rhs.startedAt ? lhs.startedAt < rhs.startedAt : lhs.createdAt < rhs.createdAt }
    }

    public func session(id: UUID) async throws -> WorkoutSession? {
        stored[id]
    }

    public func save(_ session: WorkoutSession) async throws {
        stored[session.id] = session
    }

    public func delete(id: UUID) async throws {
        stored[id] = nil
    }

    /// Séries hors échauffement de la dernière séance terminée ou abandonnée contenant l'exercice et commencée avant `date`,
    /// dans l'ordre.
    public func lastSets(for exercise: ExerciseReference, startedBefore date: Date) async throws -> [WorkoutSet] {
        let finished = stored.values.filter { $0.status != .inProgress && $0.startedAt < date }.sorted { lhs, rhs in
            lhs.startedAt != rhs.startedAt ? lhs.startedAt > rhs.startedAt : lhs.createdAt > rhs.createdAt
        }
        for session in finished {
            let sets = session.sets.filter { $0.exercise == exercise && $0.setType != .warmup }
            if !sets.isEmpty {
                return sets.sorted { $0.order < $1.order }
            }
        }
        return []
    }
}

/// Les compléments et leurs prises en mémoire, triés comme le dépôt SwiftData ; `delete` les retire.
public actor InMemorySupplementRepository: SupplementRepository {
    private var stored: [UUID: Supplement] = [:]
    private var storedIntakes: [UUID: SupplementIntake] = [:]

    public init(supplements: [Supplement] = [], intakes: [SupplementIntake] = []) {
        for supplement in supplements { stored[supplement.id] = supplement }
        for intake in intakes { storedIntakes[intake.id] = intake }
    }

    public func supplements(includeArchived: Bool) async throws -> [Supplement] {
        stored.values.filter { includeArchived || !$0.isArchived }
            .sorted { lhs, rhs in lhs.order != rhs.order ? lhs.order < rhs.order : lhs.createdAt < rhs.createdAt }
    }

    public func save(_ supplement: Supplement) async throws {
        stored[supplement.id] = supplement
    }

    public func delete(id: UUID) async throws {
        stored[id] = nil
    }

    public func intakes(from: Date, to: Date) async throws -> [SupplementIntake] {
        storedIntakes.values.filter { $0.takenAt >= from && $0.takenAt < to }
            .sorted { lhs, rhs in lhs.takenAt != rhs.takenAt ? lhs.takenAt < rhs.takenAt : lhs.createdAt < rhs.createdAt }
    }

    public func save(_ intake: SupplementIntake) async throws {
        storedIntakes[intake.id] = intake
    }

    public func delete(intakeID: UUID) async throws {
        storedIntakes[intakeID] = nil
    }
}
