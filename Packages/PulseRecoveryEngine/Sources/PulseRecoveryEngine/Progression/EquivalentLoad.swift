import PulseDomain

/// La charge équivalente au remplacement d'un exercice sans historique (spec M4 §8.3) : le 1RM estimé de l'exercice remplacé,
/// passé d'un matériel à l'autre par un coefficient, puis ramené aux répétitions visées par Brzycki inversé. C'est une
/// approximation, affichée comme une proposition à ajuster.
public enum EquivalentLoad {
    /// La force qu'un matériel laisse exprimer, rapportée à la barre **(choix du constructeur, approximation)**. Les haltères
    /// et la kettlebell comptent la charge d'une seule main, comme on les note ; la machine guidée et la Smith aident un peu ;
    /// la poulie perd par ses renvois. L'élastique et le poids du corps n'ont pas de charge comparable.
    private static func strength(_ equipment: Equipment) -> Double? {
        switch equipment {
        case .barbell: 1
        case .smithMachine: 1.05
        case .ezBar: 0.9
        case .machine: 1.1
        case .cable: 0.7
        case .dumbbell: 0.4
        case .kettlebell: 0.35
        case .band, .bodyweight: nil
        }
    }

    /// Le coefficient de `from` vers `to` ; `nil` quand l'un des deux n'a pas de charge comparable. Aller puis revenir donne 1.
    public static func coefficient(from: Equipment, to: Equipment) -> Double? {
        guard let source = strength(from), let target = strength(to) else { return nil }
        return target / source
    }

    /// La charge proposée sur l'exercice de remplacement pour `targetReps` répétitions, quand on passe du matériel
    /// `switching.from` au matériel `switching.to`, arrondie à ce qui se charge (jamais moins que la barre), ou `nil` sans 1RM,
    /// sans répétitions ou entre matériels incomparables. Au-delà de 20 répétitions,
    /// l'estimation s'arrête à 20 : Brzycki ne vaut plus grand-chose au-delà.
    public static func estimate(oneRepMaxKg: Double, switching: (from: Equipment, to: Equipment), targetReps: Int,
                                rounding: WeightRounding, incrementKg: Double) -> Double? {
        guard oneRepMaxKg > 0, targetReps > 0,
              let coefficient = coefficient(from: switching.from, to: switching.to) else { return nil }
        let reps = Double(min(targetReps, 20))
        let raw = oneRepMaxKg * coefficient * (37 - reps) / 36
        let load = PlateRounding.nearestLoad(raw, increment: incrementKg, rounding: rounding)
        if case .plates(let barKg, _) = rounding { return max(load, barKg) }
        return load > 0 ? load : nil
    }
}
