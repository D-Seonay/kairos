import Foundation
import PulseDomain
import PulseRecoveryEngine

/// La baisse des charges proposée à un exercice (`LoadDropRule`) : la ligne qui l'explique sur la carte, et les charges de la
/// dernière fois, que « Remettre » reprend d'un geste. Ce n'est qu'une proposition.
public struct LiveLoadDrop: Sendable, Equatable, Codable {
    /// « Reprise après 5 semaines : −15 % ».
    public var text: String
    /// Les propositions sans la baisse, série de travail par série de travail : la charge de la dernière fois (décharge en
    /// cours comprise), jamais la hausse qu'elle aurait value, et les répétitions proposées.
    public var originalSets: [ProposedSet]
    /// Les séries de travail planifiées, dans l'ordre de `originalSets` : « Remettre » retrouve chaque série par son identité,
    /// même après une série supprimée. `nil` : relue d'avant, la série *n* reprend la proposition *n*.
    public var setIDs: [UUID]?

    public init(text: String, originalSets: [ProposedSet], setIDs: [UUID]? = nil) {
        self.text = text
        self.originalSets = originalSets
        self.setIDs = setIDs
    }

    /// Ce que « Remettre » repose sur la série `id`, à la place `position` parmi les séries de travail.
    func original(for id: UUID, position: Int) -> ProposedSet? {
        let index = setIDs.map { $0.firstIndex(of: id) } ?? position
        guard let index, originalSets.indices.contains(index) else { return nil }
        return originalSets[index]
    }

    /// La charge d'avant la baisse quand toutes les séries la partagent : le « 80 kg » de « Remettre 80 kg ».
    public var originalWeightKg: Double? {
        let weights = Set(originalSets.compactMap(\.weightKg))
        return weights.count == 1 ? weights.first : nil
    }
}

extension LiveSessionPlanner {
    /// Ce que le planificateur lit des dernières séances d'un exercice : la pause depuis la dernière fois, les échecs répétés
    /// et la note à reprendre. `recent` va de la plus récente à la plus ancienne, décharges comprises.
    struct Recall {
        var recent: [RecentExerciseSession]
        var start: Date
        var calendar: Calendar

        /// Les jours de calendrier depuis la dernière séance avec l'exercice, comptés comme le plateau, `nil` sans aucune.
        var daysSinceLast: Int? {
            recent.first.map { LoadDropRule.calendarDays(from: $0.startedAt, to: start, calendar: calendar) }
        }

        /// La note de la dernière séance avec l'exercice : la séance suivante la reprend, modifiable.
        var pinnedNote: String? { recent.first?.note }

        func drop(for exercise: RoutineExercise, tracksDuration: Bool) -> LoadDrop? {
            LoadDropRule.drop(daysSinceLast: daysSinceLast, recentSets: recent.filter { !$0.isDeloaded }.map(\.sets),
                              exercise: exercise, tracksDuration: tracksDuration)
        }
    }

    // swiftlint:disable function_parameter_count
    /// Les séries proposées avec la baisse du jour, s'il y en a une : seulement pour une charge externe, et seulement quand
    /// elle baisse plus que la décharge en cours (`loadFactor`), qui sinon suffit. `proposed` : les séries déjà passées par la
    /// décharge. « Remettre » reprend leurs répétitions avec la charge de la dernière fois (`restoredSets`).
    static func applyingDrop(_ drop: LoadDrop?, to proposed: [ProposedSet], routineExercise: RoutineExercise,
                             lastSets: [WorkoutSet], loadKind: LoadKind, tracksDuration: Bool, incrementKg: Double,
                             rounding: WeightRounding, loadFactor: Double) -> (sets: [ProposedSet], drop: LiveLoadDrop?) {
        guard let drop, loadKind == .external, drop.factor < loadFactor,
              let lowered = LoadDropRule.lowered(proposed, lastSets: lastSets, exercise: routineExercise,
                                                 tracksDuration: tracksDuration, drop: drop, incrementKg: incrementKg,
                                                 rounding: rounding) else { return (proposed, nil) }
        let restored = restoredSets(proposed, lastSets: lastSets, incrementKg: incrementKg, rounding: rounding,
                                    loadFactor: loadFactor)
        return (lowered, LiveLoadDrop(text: drop.text, originalSets: restored))
    }
    // swiftlint:enable function_parameter_count

    /// Ce que « Remettre » repose : la série *n* reprend la charge de la série *n* de la dernière fois (la dernière série faute
    /// de mieux), multipliée par la décharge en cours, avec les répétitions proposées. Si la dernière fois avait atteint le haut
    /// de la fourchette, la hausse n'est pas reprise : « l'ancien poids », 80 kg, pas 82,5 kg. Une série sans charge de
    /// référence garde sa proposition.
    static func restoredSets(_ proposed: [ProposedSet], lastSets: [WorkoutSet], incrementKg: Double, rounding: WeightRounding,
                             loadFactor: Double) -> [ProposedSet] {
        proposed.enumerated().map { index, set in
            let reference = lastSets.indices.contains(index) ? lastSets[index] : lastSets.last
            guard let lastKg = reference?.actualWeightKg, lastKg > 0 else { return set }
            var restored = set
            restored.weightKg = scaled([ProposedSet(weightKg: lastKg, reps: nil)], by: loadFactor, increment: incrementKg,
                                       rounding: rounding).first?.weightKg ?? lastKg
            restored.isIncrease = false
            return restored
        }
    }
}
