import Foundation
import PulseDomain

/// Une baisse proposée des charges d'un exercice : après une pause, ou après deux séances de suite sous la fourchette.
public struct LoadDrop: Sendable, Equatable, Codable {
    public enum Reason: Sendable, Equatable, Codable {
        /// Une reprise après `weeks` semaines pleines sans l'exercice.
        case layoff(weeks: Int)
        /// Deux séances de suite où le bas de la fourchette n'a pas été atteint.
        case misses
    }

    public var reason: Reason
    /// La baisse en pour cent : 15 pour −15 %.
    public var percent: Int

    public init(reason: Reason, percent: Int) {
        self.reason = reason
        self.percent = percent
    }

    /// Le facteur des charges : 0,85 pour −15 %.
    public var factor: Double { 1 - Double(percent) / 100 }

    /// « Reprise après 5 semaines : −15 % », « Deux séances sous la fourchette : −5 % ».
    public var text: String {
        switch reason {
        case .layoff(let weeks):
            String(localized: "Reprise après \(weeks) semaines : −\(percent) %", bundle: .module)
        case .misses:
            String(localized: "Deux séances sous la fourchette : −\(percent) %", bundle: .module)
        }
    }
}

/// Quand et de combien baisser les charges proposées d'un exercice. Pur : l'historique est lu avant l'appel.
///
/// **Reprise.** La pause se compte en semaines pleines depuis la dernière séance avec l'exercice (décharge comprise) :
///
/// | Pause         | Baisse |
/// |---------------|--------|
/// | moins de 2 sem. | aucune |
/// | 2 semaines    | −5 %   |
/// | 3 à 4 semaines | −10 % |
/// | 5 semaines    | −15 %  |
/// | 6 semaines et plus | −20 % |
///
/// La force se perd peu sur deux semaines, puis plus nettement ; au-delà de six semaines, −20 % suffit à repartir sans
/// échec, et la double progression remonte vite.
///
/// **Échecs répétés.** Une séance « sous la fourchette » a au moins une série de travail ou à l'échec (ni échauffement, ni
/// dégressive, ni série sans répétitions saisies) sous sa propre cible : les répétitions proposées ce jour-là, ou le bas de la
/// fourchette de sa série dans la routine d'aujourd'hui s'il est plus bas. Un squat fait en 5 × 5 n'échoue donc pas quand la
/// fourchette du jour est 8–12 (exercice ajouté en séance, changement de programme). Une série sans répétitions proposées
/// (importée, exercice tenu) ne dit pas sa cible : elle n'est pas comptée. Deux séances de suite ainsi, hors décharge : −5 %,
/// ou −10 % quand plus de la moitié des séries comptées ont manqué les deux fois.
/// Une reprise passe avant : les séances d'avant la pause ne disent plus grand-chose.
public enum LoadDropRule {
    /// À partir de deux semaines sans l'exercice, la séance est une reprise.
    public static let layoffDays = 14
    static let missPercent = 5
    static let heavyMissPercent = 10

    /// La baisse d'une reprise après `days` jours sans l'exercice, `nil` avant deux semaines.
    public static func layoffPercent(daysSinceLast days: Int) -> Int? {
        switch days / 7 {
        case ..<2: nil
        case 2: 5
        case 3, 4: 10
        case 5: 15
        default: 20
        }
    }

    /// La baisse du jour, ou `nil`. `daysSinceLast` : les jours depuis la dernière séance avec l'exercice ; `recentSets` : les
    /// séries hors échauffement de ses dernières séances hors décharge, de la plus récente à la plus ancienne. Pour un
    /// exercice tenu, la fourchette se lit en secondes.
    public static func drop(daysSinceLast: Int?, recentSets: [[WorkoutSet]], exercise: RoutineExercise,
                            tracksDuration: Bool) -> LoadDrop? {
        if let days = daysSinceLast, let percent = layoffPercent(daysSinceLast: days) {
            return LoadDrop(reason: .layoff(weeks: days / 7), percent: percent)
        }
        guard recentSets.count >= 2 else { return nil }
        let tallies = recentSets.prefix(2).map { misses(in: $0, exercise: exercise, tracksDuration: tracksDuration) }
        guard tallies.allSatisfy({ $0.missed > 0 }) else { return nil }
        let heavy = tallies.allSatisfy { 2 * $0.missed > $0.checked }
        return LoadDrop(reason: .misses, percent: heavy ? heavyMissPercent : missPercent)
    }

    /// Les séries comptées d'une séance et celles sous leur cible : les répétitions proposées ce jour-là, ou le bas de la
    /// fourchette de la série *n* de la routine s'il est plus bas. Sans cible enregistrée, la série n'est pas comptée. Un
    /// exercice tenu n'enregistre pas sa durée prévue : aucune de ses séries ne compte.
    static func misses(in sets: [WorkoutSet], exercise: RoutineExercise, tracksDuration: Bool) -> (checked: Int, missed: Int) {
        guard !tracksDuration else { return (0, 0) }
        var checked = 0
        var missed = 0
        for (index, set) in sets.enumerated() where set.setType == .working || set.setType == .failure {
            guard let reached = set.actualReps, let planned = set.plannedReps else { continue }
            checked += 1
            if reached < min(exercise.repRange(forSet: index).lowerBound, planned) { missed += 1 }
        }
        return (checked, missed)
    }

    /// `weightKg` baissé de `factor`, arrondi à la charge faisable la plus proche, et toujours au moins un cran plus bas ;
    /// inchangé quand rien ne descend plus (la barre seule, une charge nulle).
    public static func lower(_ weightKg: Double, factor: Double, incrementKg: Double, rounding: WeightRounding) -> Double {
        let nearest = PlateRounding.nearestLoad(weightKg * factor, increment: incrementKg, rounding: rounding)
        if nearest < weightKg { return nearest }
        let step = PlateRounding.floorLoad(weightKg - max(incrementKg, 0.01), increment: incrementKg, rounding: rounding)
        return step < weightKg && step >= 0 ? step : weightKg
    }

    // swiftlint:disable function_parameter_count
    /// Les séries proposées après la baisse : la série *n* repart de la charge de la série *n* de la dernière fois (la
    /// dernière série faute de mieux), baissée, au bas de sa fourchette, sans hausse. Une série sans charge de référence garde
    /// sa proposition. `nil` quand aucune charge ne baisse : la baisse n'a alors pas lieu d'être dite.
    public static func lowered(_ proposed: [ProposedSet], lastSets: [WorkoutSet], exercise: RoutineExercise, tracksDuration: Bool,
                               drop: LoadDrop, incrementKg: Double, rounding: WeightRounding) -> [ProposedSet]? {
        var anyLowered = false
        let sets = proposed.enumerated().map { index, set -> ProposedSet in
            let reference = lastSets.indices.contains(index) ? lastSets[index] : lastSets.last
            guard let weightKg = reference?.actualWeightKg ?? set.weightKg, weightKg > 0 else { return set }
            let lowered = lower(weightKg, factor: drop.factor, incrementKg: incrementKg, rounding: rounding)
            guard lowered < weightKg else { return set }
            anyLowered = true
            let bottom = exercise.repRange(forSet: index).lowerBound
            return ProposedSet(weightKg: lowered, reps: tracksDuration ? nil : bottom, durationSeconds: tracksDuration ? bottom : nil)
        }
        return anyLowered ? sets : nil
    }
    // swiftlint:enable function_parameter_count
}
