import Foundation
import PulseDomain

/// Calcule les records personnels depuis l'historique des séances (spec M4 §8.2).
public enum RecordBook {
    public struct Result: Sendable, Equatable {
        public var records: [PersonalRecord]
        public var recordSetIDs: Set<UUID>

        public init(records: [PersonalRecord] = [], recordSetIDs: Set<UUID> = []) {
            self.records = records
            self.recordSetIDs = recordSetIDs
        }
    }

    /// Une valeur qui dépasse (ou fonde) le record d'un exercice dans une séance.
    private struct Finding {
        var kind: RecordKind
        var value: Double
        var weightKg: Double
        var set: WorkoutSet
    }

    /// Les meilleures valeurs des séances précédentes d'un exercice.
    private struct History {
        var maxWeight: Double?
        var oneRepMax: Double?
        var repsAtWeight: [Double: Int] = [:]
    }

    public static func compute(sessions: [WorkoutSession], loadKind: (ExerciseReference) -> LoadKind, now: Date) -> Result {
        let ordered = sessions
            .filter { $0.status == .completed || $0.status == .abandoned }
            .sorted { $0.startedAt < $1.startedAt }
        var histories: [ExerciseReference: History] = [:]
        var result = Result()
        for session in ordered {
            for (exercise, sets) in groupedByExercise(session.sets) {
                let kind = loadKind(exercise)
                let prior = histories[exercise]
                for finding in findings(in: sets, kind: kind, prior: prior) {
                    result.records.append(record(for: finding, in: session, now: now))
                    if prior != nil { result.recordSetIDs.insert(finding.set.id) }
                }
                histories[exercise] = merged(prior, with: sets, kind: kind)
            }
        }
        return result
    }

    private static func record(for finding: Finding, in session: WorkoutSession, now: Date) -> PersonalRecord {
        PersonalRecord(exercise: finding.set.exercise, exerciseName: finding.set.exerciseName, kind: finding.kind,
                       value: finding.value, weightKg: finding.weightKg, date: session.startedAt, sessionID: session.id,
                       setID: finding.set.id, createdAt: now, updatedAt: now)
    }

    /// Séries comptées (hors échauffement, avec des répétitions), regroupées par exercice dans l'ordre de la séance.
    private static func groupedByExercise(_ sets: [WorkoutSet]) -> [(ExerciseReference, [WorkoutSet])] {
        var order: [ExerciseReference] = []
        var groups: [ExerciseReference: [WorkoutSet]] = [:]
        for set in sets.sorted(by: { $0.order < $1.order }) where set.setType != .warmup && (set.actualReps ?? 0) > 0 {
            if groups[set.exercise] == nil { order.append(set.exercise) }
            groups[set.exercise, default: []].append(set)
        }
        return order.map { ($0, groups[$0] ?? []) }
    }

    /// La charge sur laquelle une série compte : positive en charge externe, lest (ou zéro) sinon.
    private static func weight(of set: WorkoutSet, kind: LoadKind) -> Double? {
        switch kind {
        case .external: (set.actualWeightKg ?? 0) > 0 ? set.actualWeightKg : nil
        case .bodyweight, .assisted: set.actualWeightKg ?? 0
        }
    }

    private static func findings(in sets: [WorkoutSet], kind: LoadKind, prior: History?) -> [Finding] {
        var found: [Finding] = []
        if kind == .external {
            found += maxWeightFinding(in: sets, prior: prior)
            found += oneRepMaxFinding(in: sets, prior: prior)
        }
        if let prior {
            found += repsAtWeightFindings(in: sets, kind: kind, prior: prior)
        }
        return found
    }

    private static func maxWeightFinding(in sets: [WorkoutSet], prior: History?) -> [Finding] {
        var best: Finding?
        for set in sets {
            guard let weight = weight(of: set, kind: .external), weight > (best?.value ?? 0) else { continue }
            best = Finding(kind: .maxWeight, value: weight, weightKg: weight, set: set)
        }
        guard let best, best.value > (prior?.maxWeight ?? 0) else { return [] }
        return [best]
    }

    private static func oneRepMaxFinding(in sets: [WorkoutSet], prior: History?) -> [Finding] {
        var best: Finding?
        for set in sets {
            guard let weight = weight(of: set, kind: .external), let reps = set.actualReps,
                  let estimate = OneRepMax.brzycki(weightKg: weight, reps: reps), estimate > (best?.value ?? 0) else { continue }
            best = Finding(kind: .estimatedOneRepMax, value: estimate, weightKg: weight, set: set)
        }
        guard let best, best.value > (prior?.oneRepMax ?? 0) else { return [] }
        return [best]
    }

    /// Une ligne par charge déjà faite lors d'une séance précédente, quand les répétitions dépassent le meilleur d'alors.
    private static func repsAtWeightFindings(in sets: [WorkoutSet], kind: LoadKind, prior: History) -> [Finding] {
        bestRepsByWeight(in: sets, kind: kind)
            .sorted { $0.key < $1.key }
            .compactMap { weight, set in
                guard let reps = set.actualReps, let previous = prior.repsAtWeight[weight], reps > previous else { return nil }
                return Finding(kind: .repsAtWeight, value: Double(reps), weightKg: weight, set: set)
            }
    }

    private static func bestRepsByWeight(in sets: [WorkoutSet], kind: LoadKind) -> [Double: WorkoutSet] {
        var best: [Double: WorkoutSet] = [:]
        for set in sets {
            guard let weight = weight(of: set, kind: kind), let reps = set.actualReps else { continue }
            if reps > (best[weight]?.actualReps ?? 0) { best[weight] = set }
        }
        return best
    }

    private static func merged(_ prior: History?, with sets: [WorkoutSet], kind: LoadKind) -> History {
        var history = prior ?? History()
        for set in sets {
            guard let weight = weight(of: set, kind: kind), let reps = set.actualReps else { continue }
            history.repsAtWeight[weight] = max(history.repsAtWeight[weight] ?? 0, reps)
            guard kind == .external else { continue }
            history.maxWeight = max(history.maxWeight ?? 0, weight)
            if let estimate = OneRepMax.brzycki(weightKg: weight, reps: reps) {
                history.oneRepMax = max(history.oneRepMax ?? 0, estimate)
            }
        }
        return history
    }
}
