/// Une série d'échauffement proposée : hors volume et hors records.
public struct WarmupSet: Sendable, Equatable {
    public let weightKg: Double
    public let reps: Int

    public init(weightKg: Double, reps: Int) {
        self.weightKg = weightKg
        self.reps = reps
    }
}

/// L'échauffement automatique (spec M4 §8.3) : avant la première série de travail d'un polyarticulaire, la barre seule (sur
/// une barre), puis 60 % et 80 % de la première charge de travail, arrondis vers le bas à ce qui se charge.
public enum WarmupPlanner {
    /// Le repos après une série d'échauffement.
    public static let restSeconds = 60

    /// Les étapes : part de la charge de travail et répétitions. La barre seule fait 10 répétitions, 60 % en fait 5, 80 % en
    /// fait 3 **(choix du constructeur)** : assez pour chauffer, trop peu pour fatiguer.
    private static let steps: [(share: Double, reps: Int)] = [(0.6, 5), (0.8, 3)]
    private static let barReps = 10

    /// Pulse échauffe-t-il cet exercice ? Il faut l'échauffement automatique activé et un muscle principal pas encore travaillé
    /// dans la séance ; puis un polyarticulaire, ou un réglage de l'exercice qui en demande. Un réglage à 0 l'éteint.
    public static func isEligible(autoWarmupEnabled: Bool, isCompound: Bool, warmupSetCount: Int?,
                                  primaryMuscleAlreadyWorked: Bool) -> Bool {
        guard autoWarmupEnabled, !primaryMuscleAlreadyWorked, warmupSetCount != 0 else { return false }
        return isCompound || (warmupSetCount ?? 0) > 0
    }

    /// Les séries d'échauffement pour une première série de travail à `firstWorkingKg`. Une série qui retombe sur la barre
    /// seule ou sur une charge déjà prévue disparaît, comme toute série qui atteint la charge de travail. `maxCount` garde les
    /// séries les plus proches de la charge de travail ; `nil` les garde toutes.
    public static func sets(firstWorkingKg: Double, rounding: WeightRounding, incrementKg: Double, maxCount: Int?) -> [WarmupSet] {
        guard firstWorkingKg > 0 else { return [] }
        var sets: [WarmupSet] = []
        if case .plates(let barKg, _) = rounding, barKg > 0 {
            sets.append(WarmupSet(weightKg: barKg, reps: barReps))
        }
        for step in steps {
            let weight = PlateRounding.floorLoad(firstWorkingKg * step.share, increment: incrementKg, rounding: rounding)
            guard weight > 0, !sets.contains(where: { abs($0.weightKg - weight) < 0.001 }) else { continue }
            sets.append(WarmupSet(weightKg: weight, reps: step.reps))
        }
        sets.removeAll { $0.weightKg >= firstWorkingKg - 0.001 }
        guard let maxCount else { return sets }
        return Array(sets.suffix(max(0, maxCount)))
    }
}
