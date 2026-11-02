import Foundation
import PulseDomain
import PulseRecoveryEngine

/// Un geste sur la séance en cours (spec M4 §14.3 à §14.5, §15.1). `ActiveSessionService.apply(_:)` l'applique, l'enregistre,
/// puis règle le repos, sa notification et la Live Activity. Un identifiant inconnu (série déjà supprimée…) ne change aucune
/// série ni aucun exercice.
public enum LiveSessionChange: Sendable, Equatable {
    /// Valide la série : les valeurs non modifiées prennent la proposition. Pour un exercice sans historique, la première série
    /// validée devient la proposition des séries suivantes non modifiées (spec M4 §14.5).
    case validate(exercise: UUID, set: UUID)
    case unvalidate(exercise: UUID, set: UUID)
    /// `nil` laisse une valeur telle quelle, `.some(nil)` l'efface. Changer la charge, les répétitions ou la durée marque la
    /// série modifiée ; le RPE, qui n'est jamais proposé, non.
    case edit(exercise: UUID, set: UUID, weightKg: Double?? = nil, reps: Int?? = nil, durationSeconds: Int?? = nil,
              rpe: Double?? = nil)
    case setType(exercise: UUID, set: UUID, SetType)
    /// Ajoute une série qui reprend les valeurs de la dernière.
    case addSet(exercise: UUID)
    case deleteSet(exercise: UUID, set: UUID)
    case addExercises([LiveExercise])
    case removeExercise(UUID)
    /// Déplace l'exercice de `by` places, dans les limites de la séance.
    case moveExercise(UUID, by: Int)
    /// Une note vide efface la note.
    case setNote(exercise: UUID, String?)
    /// Un incrément nul ou négatif est ignoré.
    case setIncrement(exercise: UUID, Double)
    case restMinus30
    case restPlus30
    case skipRest
}

extension LiveSession {
    /// Applique les changements de séries et d'exercices. Le repos est réglé à part (`ActiveSessionService+Rest`).
    mutating func applyStructure(_ change: LiveSessionChange, now: Date) {
        switch change {
        case .validate, .unvalidate, .edit, .setType, .addSet, .deleteSet:
            applySetChange(change, now: now)
        case .addExercises, .removeExercise, .moveExercise, .setNote, .setIncrement:
            applyExerciseChange(change)
        case .restMinus30, .restPlus30, .skipRest:
            return
        }
    }

    private mutating func applySetChange(_ change: LiveSessionChange, now: Date) {
        switch change {
        case let .validate(exercise, set):
            validate(exercise: exercise, set: set, now: now)
        case let .unvalidate(exercise, set):
            updateSet(set, of: exercise) { $0.completedAt = nil }
        case let .edit(exercise, set, weightKg, reps, durationSeconds, rpe):
            updateSet(set, of: exercise) { $0.edit(weightKg: weightKg, reps: reps, durationSeconds: durationSeconds, rpe: rpe) }
        case let .setType(exercise, set, type):
            updateSet(set, of: exercise) { $0.setType = type }
        case let .addSet(exercise):
            updateExercise(exercise) { $0.sets.append(Self.copy(of: $0.sets.last)) }
        case let .deleteSet(exercise, set):
            updateExercise(exercise) { $0.sets.removeAll { $0.id == set } }
        default:
            return
        }
    }

    private mutating func applyExerciseChange(_ change: LiveSessionChange) {
        switch change {
        case let .addExercises(added):
            exercises.append(contentsOf: added)
        case let .removeExercise(exercise):
            exercises.removeAll { $0.id == exercise }
        case let .moveExercise(exercise, offset):
            move(exercise, by: offset)
        case let .setNote(exercise, note):
            let trimmed = note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            updateExercise(exercise) { $0.note = trimmed.isEmpty ? nil : trimmed }
        case let .setIncrement(exercise, incrementKg):
            guard incrementKg > 0 else { return }
            updateExercise(exercise) { $0.incrementKg = incrementKg }
        default:
            return
        }
    }

    /// La série, si l'exercice et la série existent encore.
    func set(_ set: UUID, of exercise: UUID) -> LiveSet? {
        exercises.first { $0.id == exercise }?.sets.first { $0.id == set }
    }

    private mutating func validate(exercise exerciseID: UUID, set setID: UUID, now: Date) {
        guard let exerciseIndex = exercises.firstIndex(where: { $0.id == exerciseID }),
              let setIndex = exercises[exerciseIndex].sets.firstIndex(where: { $0.id == setID }),
              exercises[exerciseIndex].sets[setIndex].completedAt == nil else { return }
        var exercise = exercises[exerciseIndex]
        var set = exercise.sets[setIndex]
        if !set.isEdited {
            set.weightKg = set.proposed.weightKg
            set.reps = set.proposed.reps
            set.durationSeconds = set.proposed.durationSeconds
        }
        set.completedAt = now
        // Sans historique, la première série de travail validée sert de référence aux suivantes (spec M4 §14.5).
        let seeds = exercise.lastTimeText == nil && set.setType != .warmup
            && !exercise.sets.contains { $0.completedAt != nil && $0.setType != .warmup }
        exercise.sets[setIndex] = set
        if seeds {
            let proposal = ProposedSet(weightKg: set.weightKg, reps: set.reps, durationSeconds: set.durationSeconds)
            for index in exercise.sets.indices.dropFirst(setIndex + 1) {
                let next = exercise.sets[index]
                guard !next.isEdited, next.completedAt == nil, next.setType != .warmup else { continue }
                exercise.sets[index] = LiveSet(id: next.id, setType: next.setType, previous: next.previous, proposed: proposal,
                                               weightKg: proposal.weightKg, reps: proposal.reps,
                                               durationSeconds: proposal.durationSeconds, rpe: next.rpe)
            }
        }
        exercises[exerciseIndex] = exercise
    }

    /// Une nouvelle série aux valeurs de `last`, proposées et non modifiées.
    private static func copy(of last: LiveSet?) -> LiveSet {
        guard let last else { return LiveSet(proposed: ProposedSet(), previous: nil) }
        let proposal = ProposedSet(weightKg: last.weightKg, reps: last.reps, durationSeconds: last.durationSeconds)
        var set = LiveSet(proposed: proposal, previous: nil)
        set.setType = last.setType
        return set
    }

    private mutating func move(_ exercise: UUID, by offset: Int) {
        guard let from = exercises.firstIndex(where: { $0.id == exercise }) else { return }
        let to = min(max(from + offset, 0), exercises.count - 1)
        guard to != from else { return }
        exercises.insert(exercises.remove(at: from), at: to)
    }

    private mutating func updateExercise(_ exercise: UUID, _ update: (inout LiveExercise) -> Void) {
        guard let index = exercises.firstIndex(where: { $0.id == exercise }) else { return }
        update(&exercises[index])
    }

    private mutating func updateSet(_ set: UUID, of exercise: UUID, _ update: (inout LiveSet) -> Void) {
        updateExercise(exercise) { exercise in
            guard let index = exercise.sets.firstIndex(where: { $0.id == set }) else { return }
            update(&exercise.sets[index])
        }
    }
}

private extension LiveSet {
    mutating func edit(weightKg: Double??, reps: Int??, durationSeconds: Int??, rpe: Double??) {
        if let weightKg { self.weightKg = weightKg }
        if let reps { self.reps = reps }
        if let durationSeconds { self.durationSeconds = durationSeconds }
        if let rpe { self.rpe = rpe }
        if weightKg != nil || reps != nil || durationSeconds != nil { isEdited = true }
    }
}
