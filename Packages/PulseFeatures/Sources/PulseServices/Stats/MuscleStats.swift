import Foundation
import PulseContent
import PulseDomain

/// Le nombre de séries pondérées d'un muscle.
public struct MuscleLoad: Sendable, Equatable, Identifiable {
    public var muscle: Muscle
    public var sets: Double

    public var id: Muscle { muscle }

    public init(muscle: Muscle, sets: Double) {
        self.muscle = muscle
        self.sets = sets
    }
}

/// Un groupe musculaire peu sollicité sur la période, avec ses muscles travaillés pour la phrase « Tronc peu sollicité : … ».
public struct NeglectedGroup: Sendable, Equatable, Identifiable {
    public var group: MuscleGroup
    /// Les séries pondérées du groupe, ramenées à la semaine.
    public var weeklySets: Double
    /// Les muscles du groupe qui ont au moins une série, du plus au moins travaillé.
    public var muscles: [MuscleLoad]

    public var id: MuscleGroup { group }

    public init(group: MuscleGroup, weeklySets: Double, muscles: [MuscleLoad]) {
        self.group = group
        self.weeklySets = weeklySets
        self.muscles = muscles
    }
}

/// La vue Muscles : poids par muscle pour la carte de chaleur, les plus travaillés, les groupes délaissés et l'équilibre
/// pousser / tirer et haut / bas (spec M7 §8).
public struct MuscleStats: Sendable, Equatable {
    /// Sous cette moyenne de séries pondérées par semaine, un groupe est délaissé.
    public static let neglectedWeeklySets = 4.0
    /// Le rapport de séries (pousser sur tirer, haut sur bas) qui reste équilibré.
    public static let balanceRange = 0.67...1.5
    /// La règle « délaissé » ne s'applique qu'à partir de cette période, en jours.
    static let neglectedMinimumDays = 30
    /// Sous cette durée d'historique dans la période (jours de calendrier), la moyenne hebdomadaire ne veut encore rien dire.
    static let neglectedMinimumHistoryDays = 14
    static let topCount = 8

    /// 1 par série de travail pour un muscle principal, 0,5 pour un secondaire (comme `SessionRecap`).
    public var weights: [Muscle: Double]
    /// Les huit muscles au plus haut total, à égalité dans l'ordre de `Muscle.allCases`.
    public var top: [MuscleLoad]
    /// Du groupe le moins travaillé au plus travaillé ; vide sous 30 jours ou sans séance de musculation chaque semaine.
    public var neglected: [NeglectedGroup]
    /// Les séries de travail (non pondérées) par schéma de mouvement ; le tronc n'entre ni dans haut ni dans bas.
    public var push: Int
    public var pull: Int
    public var upper: Int
    public var lower: Int
    public var isPushPullUnbalanced: Bool
    public var isUpperLowerUnbalanced: Bool
    /// Les séances de musculation terminées de la période, que leurs exercices se résolvent ou non.
    public var strengthSessions: Int

    private static let pushPatterns: Set<MovementPattern> = [.horizontalPush, .chestFly, .verticalPush, .elbowExtension]
    private static let pullPatterns: Set<MovementPattern> = [.verticalPull, .horizontalPull, .elbowFlexion]

    // swiftlint:disable function_parameter_count
    /// `historyStart` : la fin de l'onboarding ou la première séance ; la moyenne hebdomadaire ne remonte pas avant
    /// (`nil` : la période entière).
    public static func make(sessions: [WorkoutSession], directory: ExerciseDirectory, historyStart: Date?, period: StatsPeriod,
                            now: Date, calendar: Calendar) -> MuscleStats {
        let interval = period.interval(now: now, calendar: calendar)
        let completed = sessions.filter {
            $0.kind == .strength && $0.status == .completed && interval.start <= $0.startedAt && $0.startedAt < interval.end
        }
        let working = completed.flatMap(\.sets).filter { $0.setType != .warmup }
        let weights = SessionRecap.muscleWeights(of: working, directory: directory)

        var push = 0, pull = 0, upper = 0, lower = 0
        for set in working {
            guard let exercise = directory.info(set.exercise) else { continue }
            if pushPatterns.contains(exercise.pattern) { push += 1 }
            if pullPatterns.contains(exercise.pattern) { pull += 1 }
            if exercise.region == .upper { upper += 1 }
            if exercise.region == .lower { lower += 1 }
        }

        return MuscleStats(
            weights: weights, top: Array(ranked(weights).prefix(topCount)),
            neglected: neglected(weights: weights, strengthSessions: completed.count, period: period,
                                 days: clampedDays(of: interval, since: historyStart, calendar: calendar)),
            push: push, pull: pull, upper: upper, lower: lower,
            isPushPullUnbalanced: isUnbalanced(push, pull), isUpperLowerUnbalanced: isUnbalanced(upper, lower),
            strengthSessions: completed.count)
    }
    // swiftlint:enable function_parameter_count

    /// Les muscles qui ont des séries, du plus au moins travaillé ; à égalité, l'ordre de `Muscle.allCases`.
    private static func ranked(_ weights: [Muscle: Double]) -> [MuscleLoad] {
        Muscle.allCases
            .compactMap { muscle in weights[muscle].map { MuscleLoad(muscle: muscle, sets: $0) } }
            .enumerated()
            .sorted { $0.element.sets != $1.element.sets ? $0.element.sets > $1.element.sets : $0.offset < $1.offset }
            .map(\.element)
    }

    /// Les jours de calendrier de la période depuis le début de l'historique : les semaines d'avant la première séance ne comptent
    /// pas (sans `historyStart`, la période entière).
    private static func clampedDays(of interval: DateInterval, since historyStart: Date?, calendar: Calendar) -> Int {
        let start = historyStart.map { max(interval.start, calendar.startOfDay(for: $0)) } ?? interval.start
        return calendar.dateComponents([.day], from: start, to: interval.end).day ?? 0
    }

    /// Un groupe sous `neglectedWeeklySets`, quand la période compte au moins 30 jours, que l'historique couvre au moins 14 jours
    /// de la période (`days`) et qu'il y a une séance par semaine en moyenne. Un groupe sans série compte (il est délaissé),
    /// d'où le parcours de tous les groupes.
    private static func neglected(weights: [Muscle: Double], strengthSessions: Int, period: StatsPeriod, days: Int) -> [NeglectedGroup] {
        let weeks = Double(days) / 7
        guard period.days >= neglectedMinimumDays, days >= neglectedMinimumHistoryDays,
              Double(strengthSessions) / weeks >= 1 else { return [] }
        let groups = MuscleGroup.allCases.map { group -> NeglectedGroup in
            let muscles = ranked(weights).filter { MuscleGroup($0.muscle) == group }
            return NeglectedGroup(group: group, weeklySets: muscles.reduce(0) { $0 + $1.sets } / weeks, muscles: muscles)
        }
        return groups
            .filter { $0.weeklySets < neglectedWeeklySets }
            .enumerated()
            .sorted { $0.element.weeklySets != $1.element.weeklySets
                ? $0.element.weeklySets < $1.element.weeklySets : $0.offset < $1.offset }
            .map(\.element)
    }

    /// Déséquilibré quand l'un des deux a des séries et que le rapport sort de `balanceRange` ; l'autre à zéro compte aussi.
    private static func isUnbalanced(_ first: Int, _ second: Int) -> Bool {
        guard first > 0 || second > 0 else { return false }
        guard first > 0, second > 0 else { return true }
        return !balanceRange.contains(Double(first) / Double(second))
    }
}
