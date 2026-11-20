import Foundation
import PulseDomain
import PulseRecoveryEngine

/// Une série corrigée dans le détail d'une séance passée (spec M6 §8).
public struct SetCorrection: Sendable, Equatable, Identifiable {
    public var id: UUID
    public var weightKg: Double?
    public var reps: Int?
    public var durationSeconds: Int?
    public var rpe: Double?

    public init(id: UUID, weightKg: Double?, reps: Int?, durationSeconds: Int?, rpe: Double?) {
        self.id = id
        self.weightKg = weightKg
        self.reps = reps
        self.durationSeconds = durationSeconds
        self.rpe = rpe
    }

    public init(_ set: WorkoutSet) {
        self.init(id: set.id, weightKg: set.actualWeightKg, reps: set.actualReps, durationSeconds: set.durationSeconds, rpe: set.rpe)
    }
}

/// Ce qu'on peut corriger d'une séance passée : la note, le RPE global, et pour chaque série hors échauffement la charge, les
/// répétitions ou la durée tenue, le RPE ; une série peut aussi être retirée. La date, l'heure et l'entraînement écrit dans
/// Apple Santé ne bougent pas.
public struct SessionCorrection: Sendable, Equatable {
    public var note: String
    public var overallRPE: Double?
    /// Les séries hors échauffement, dans l'ordre de la séance.
    public var sets: [SetCorrection]
    public var removedSetIDs: Set<UUID>

    public init(note: String, overallRPE: Double?, sets: [SetCorrection], removedSetIDs: Set<UUID> = []) {
        self.note = note
        self.overallRPE = overallRPE
        self.sets = sets
        self.removedSetIDs = removedSetIDs
    }

    /// La séance telle qu'enregistrée.
    public init(session: WorkoutSession) {
        self.init(note: session.note ?? "", overallRPE: session.overallRPE,
                  sets: session.sets.sorted { $0.order < $1.order }.filter { $0.setType != .warmup }.map(SetCorrection.init))
    }

    /// La séance corrigée, son tonnage recalculé. Les marques de record sont recalculées ensuite par `RecordsService`.
    public func applied(to session: WorkoutSession, loadKind: (ExerciseReference) -> LoadKind, now: Date) -> WorkoutSession {
        var corrected = session
        let byID = Dictionary(sets.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })
        corrected.sets = session.sets.compactMap { set in
            guard !removedSetIDs.contains(set.id) else { return nil }
            guard let correction = byID[set.id] else { return set }
            var updated = set
            updated.actualWeightKg = correction.weightKg.flatMap { $0 > 0 ? $0 : nil }
            updated.actualReps = correction.reps.flatMap { $0 > 0 ? $0 : nil }
            updated.durationSeconds = correction.durationSeconds.flatMap { $0 > 0 ? $0 : nil }
            updated.rpe = correction.rpe
            return updated
        }
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        corrected.note = trimmed.isEmpty ? nil : trimmed
        corrected.overallRPE = overallRPE
        corrected.tonnageKg = SessionTonnage.kilograms(of: corrected.sets, loadKind: loadKind)
        if corrected != session { corrected.updatedAt = now }
        return corrected
    }
}
