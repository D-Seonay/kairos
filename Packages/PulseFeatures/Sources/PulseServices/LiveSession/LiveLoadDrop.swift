import Foundation
import PulseDomain
import PulseRecoveryEngine

/// La baisse des charges proposée à un exercice (`LoadDropRule`) : la ligne qui l'explique sur la carte, et les propositions
/// d'avant la baisse, que « Remettre » reprend d'un geste. Ce n'est qu'une proposition.
public struct LiveLoadDrop: Sendable, Equatable, Codable {
    /// « Reprise après 5 semaines : −15 % ».
    public var text: String
    /// Les propositions sans la baisse, série de travail par série de travail.
    public var originalSets: [ProposedSet]

    public init(text: String, originalSets: [ProposedSet]) {
        self.text = text
        self.originalSets = originalSets
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

        /// Les jours pleins depuis la dernière séance avec l'exercice, `nil` sans aucune.
        var daysSinceLast: Int? {
            recent.first.map { Int(start.timeIntervalSince($0.startedAt) / 86_400) }
        }

        func drop(for exercise: RoutineExercise, tracksDuration: Bool) -> LoadDrop? {
            LoadDropRule.drop(daysSinceLast: daysSinceLast, recentSets: recent.filter { !$0.isDeloaded }.map(\.sets),
                              exercise: exercise, tracksDuration: tracksDuration)
        }
    }

    // swiftlint:disable function_parameter_count
    /// Les séries proposées avec la baisse du jour, s'il y en a une : seulement pour une charge externe, et seulement quand
    /// elle baisse plus que la décharge en cours (`loadFactor`), qui sinon suffit. `proposed` : les séries déjà passées par la
    /// décharge, gardées pour « Remettre ».
    static func applyingDrop(_ drop: LoadDrop?, to proposed: [ProposedSet], routineExercise: RoutineExercise,
                             lastSets: [WorkoutSet], loadKind: LoadKind, tracksDuration: Bool, incrementKg: Double,
                             rounding: WeightRounding, loadFactor: Double) -> (sets: [ProposedSet], drop: LiveLoadDrop?) {
        guard let drop, loadKind == .external, drop.factor < loadFactor,
              let lowered = LoadDropRule.lowered(proposed, lastSets: lastSets, exercise: routineExercise,
                                                 tracksDuration: tracksDuration, drop: drop, incrementKg: incrementKg,
                                                 rounding: rounding) else { return (proposed, nil) }
        return (lowered, LiveLoadDrop(text: drop.text, originalSets: proposed))
    }
    // swiftlint:enable function_parameter_count
}
