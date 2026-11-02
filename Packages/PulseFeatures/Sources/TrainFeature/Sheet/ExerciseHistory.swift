import Foundation
import PulseDesignSystem
import PulseDomain
import PulseRecoveryEngine

/// Un point de la courbe de progression : le meilleur 1RM estimé d'une séance.
public struct ChartPoint: Identifiable, Equatable, Sendable {
    public var date: Date
    public var value: Double

    public init(date: Date, value: Double) {
        self.date = date
        self.value = value
    }

    public var id: Date { date }
}

/// Une séance d'un exercice, résumée pour la liste « Dernières séances ».
public struct ExerciseHistoryLine: Identifiable, Equatable, Sendable {
    /// L'identifiant de la séance.
    public var id: UUID
    public var date: Date
    /// Les séries hors échauffement : « 70 × 5 · 5 », « 60 × 8 · 70 × 5 · 5 », « 45 s · 40 s ».
    public var setsText: String
    public var maxRPE: Double?
    public var tonnageKg: Double
    public var hasRecord: Bool

    public init(id: UUID, date: Date, setsText: String, maxRPE: Double?, tonnageKg: Double, hasRecord: Bool) {
        self.id = id
        self.date = date
        self.setsText = setsText
        self.maxRPE = maxRPE
        self.tonnageKg = tonnageKg
        self.hasRecord = hasRecord
    }
}

/// Une série retenue comme la meilleure : sa charge, ses répétitions et la date de sa séance.
public struct BestSet: Equatable, Sendable {
    public var weightKg: Double
    public var reps: Int
    public var date: Date

    public init(weightKg: Double, reps: Int, date: Date) {
        self.weightKg = weightKg
        self.reps = reps
        self.date = date
    }
}

/// Ce que l'historique des séances dit d'un exercice : courbe, meilleure série, dernières séances. Calcul pur.
struct ExerciseHistory {
    /// Une séance terminée ou abandonnée avec ses séries réellement faites (hors échauffement) de l'exercice.
    private struct Performance {
        var session: WorkoutSession
        var sets: [WorkoutSet]
    }

    private let performances: [Performance]
    private let isExternalLoad: Bool

    /// Les séances de `sessions` où `exercise` a été fait, de la plus récente à la plus ancienne. Le 1RM estimé ne vaut que pour
    /// une charge externe, comme pour les records.
    init(sessions: [WorkoutSession], exercise: ExerciseReference, loadKind: LoadKind) {
        isExternalLoad = loadKind == .external
        performances = sessions
            .filter { $0.status == .completed || $0.status == .abandoned }
            .compactMap { session -> Performance? in
                let sets = session.sets
                    .filter { $0.exercise == exercise && $0.setType != .warmup && Self.isPerformed($0) }
                    .sorted { $0.order < $1.order }
                return sets.isEmpty ? nil : Performance(session: session, sets: sets)
            }
            .sorted { $0.session.startedAt > $1.session.startedAt }
    }

    /// Le meilleur 1RM estimé de chaque séance depuis `start`, de la plus ancienne à la plus récente.
    func chart(since start: Date) -> [ChartPoint] {
        performances
            .filter { $0.session.startedAt >= start }
            .compactMap { performance in
                bestEstimate(in: performance.sets).map { ChartPoint(date: performance.session.startedAt, value: $0) }
            }
            .reversed()
    }

    /// Le meilleur 1RM estimé des séances commencées avant `date`.
    func bestEstimate(before date: Date) -> Double? {
        performances.filter { $0.session.startedAt < date }.compactMap { bestEstimate(in: $0.sets) }.max()
    }

    /// La série au plus fort 1RM estimé, puis à la plus lourde charge, puis aux plus nombreuses répétitions ; la plus récente à égalité.
    var bestSet: BestSet? {
        var best: (set: BestSet, key: [Double])?
        for performance in performances.reversed() {
            for set in performance.sets {
                guard let reps = set.actualReps, reps > 0 else { continue }
                let weight = set.actualWeightKg ?? 0
                let key = [estimate(weight: weight, reps: reps) ?? 0, weight, Double(reps)]
                if best == nil || !key.lexicographicallyPrecedes(best?.key ?? []) {
                    best = (BestSet(weightKg: weight, reps: reps, date: performance.session.startedAt), key)
                }
            }
        }
        return best?.set
    }

    func lines(limit: Int) -> [ExerciseHistoryLine] {
        performances.prefix(limit).map { performance in
            ExerciseHistoryLine(
                id: performance.session.id, date: performance.session.startedAt, setsText: Self.setsText(performance.sets),
                maxRPE: performance.sets.compactMap(\.rpe).max(), tonnageKg: Self.tonnage(performance.sets),
                hasRecord: performance.sets.contains(where: \.isPersonalRecord))
        }
    }

    // MARK: - Interne

    private static func isPerformed(_ set: WorkoutSet) -> Bool {
        (set.actualReps ?? 0) > 0 || (set.durationSeconds ?? 0) > 0
    }

    private func estimate(weight: Double, reps: Int) -> Double? {
        isExternalLoad ? OneRepMax.brzycki(weightKg: weight, reps: reps) : nil
    }

    private func bestEstimate(in sets: [WorkoutSet]) -> Double? {
        sets.compactMap { set in set.actualReps.flatMap { estimate(weight: set.actualWeightKg ?? 0, reps: $0) } }.max()
    }

    private static func tonnage(_ sets: [WorkoutSet]) -> Double {
        sets.reduce(0) { $0 + ($1.actualWeightKg ?? 0) * Double($1.actualReps ?? 0) }
    }

    /// Les séries de même charge se suivent derrière une seule charge : « 70 × 5 · 5 ». Une série sans charge n'affiche que ses
    /// répétitions, une série chronométrée que sa durée.
    private static func setsText(_ sets: [WorkoutSet]) -> String {
        var groups: [(weight: Double, tokens: [String])] = []
        for set in sets {
            let weight = set.actualWeightKg ?? 0
            let token = set.actualReps.map(String.init) ?? PulseFormat.restDuration(seconds: set.durationSeconds ?? 0)
            if let last = groups.last, last.weight == weight {
                groups[groups.count - 1].tokens.append(token)
            } else {
                groups.append((weight, [token]))
            }
        }
        return groups.map { group in
            let tokens = group.tokens.joined(separator: " · ")
            guard group.weight > 0 else { return tokens }
            return "\(PulseFormat.decimal(group.weight, maxFractionDigits: 2)) × \(tokens)"
        }.joined(separator: " · ")
    }
}
