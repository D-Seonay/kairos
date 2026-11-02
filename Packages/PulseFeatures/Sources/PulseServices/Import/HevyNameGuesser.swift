import PulseContent
import PulseDomain

/// Devine les caractéristiques d'un exercice Hevy inconnu à partir de son nom, pour préremplir l'exercice perso à créer.
public enum HevyNameGuesser {
    private struct Rule {
        let keywords: [String]
        let muscle: Muscle
        let pattern: MovementPattern
    }

    /// Dans l'ordre : le premier mot-clé trouvé dans le nom replié décide.
    private static let rules: [Rule] = [
        Rule(keywords: ["poignet", "avant bras", "wrist"], muscle: .forearms, pattern: .forearm),
        Rule(keywords: ["shrug"], muscle: .traps, pattern: .shoulderIsolation),
        Rule(keywords: ["oiseau", "reverse fly", "face pull"], muscle: .rearDelts, pattern: .shoulderIsolation),
        Rule(keywords: ["elevation laterale", "lateral"], muscle: .sideDelts, pattern: .shoulderIsolation),
        Rule(keywords: ["developpe militaire", "presse epaules", "shoulder press", "overhead press"], muscle: .frontDelts,
             pattern: .verticalPush),
        Rule(keywords: ["dips", "triceps", "pushdown"], muscle: .triceps, pattern: .elbowExtension),
        Rule(keywords: ["curl jambe", "leg curl"], muscle: .hamstrings, pattern: .kneeFlexion),
        Rule(keywords: ["curl"], muscle: .biceps, pattern: .elbowFlexion),
        Rule(keywords: ["ecarte", "butterfly", "fly", "pec deck"], muscle: .chest, pattern: .chestFly),
        Rule(keywords: ["developpe", "bench", "chest press", "pompe"], muscle: .chest, pattern: .horizontalPush),
        Rule(keywords: ["traction", "tirage haut", "tirage poitrine", "pulldown", "pull up"], muscle: .lats, pattern: .verticalPull),
        Rule(keywords: ["rowing", "row", "tirage bas", "tirage assis", "tirage"], muscle: .upperBack, pattern: .horizontalPull),
        Rule(keywords: ["extension dos", "hyperextension", "lombaire"], muscle: .lowerBack, pattern: .hinge),
        Rule(keywords: ["souleve", "deadlift", "hip thrust"], muscle: .hamstrings, pattern: .hinge),
        Rule(keywords: ["extension jambe", "leg extension"], muscle: .quads, pattern: .kneeExtension),
        Rule(keywords: ["mollet", "calf"], muscle: .calves, pattern: .calfRaise),
        Rule(keywords: ["abduction"], muscle: .abductors, pattern: .hipAbduction),
        Rule(keywords: ["adduction"], muscle: .adductors, pattern: .hipAdduction),
        Rule(keywords: ["fente", "lunge"], muscle: .quads, pattern: .lunge),
        Rule(keywords: ["squat", "presse", "leg press"], muscle: .quads, pattern: .squat),
        Rule(keywords: ["crunch", "abdo", "oblique", "toes", "releve"], muscle: .abs, pattern: .coreFlexion),
        Rule(keywords: ["planche", "plank"], muscle: .abs, pattern: .coreStability)
    ]

    /// Matériel : premier groupe de mots-clés trouvé, dans cet ordre. Un « machine » écrit dans le nom l'emporte sur les mots
    /// du poids du corps (« Machine Dips Assis » reste une machine).
    private static let equipmentRules: [(keywords: [String], equipment: Equipment)] = [
        (["barre ez", "ez"], .ezBar),
        (["barre", "barbell"], .barbell),
        (["haltere", "dumbbell"], .dumbbell),
        (["poulie", "cable", "corde"], .cable),
        (["smith"], .smithMachine),
        (["elastique", "band"], .band),
        (["machine"], .machine),
        (["poids du corps", "traction", "dips", "lestee"], .bodyweight)
    ]

    private static let lowerPatterns: Set<MovementPattern> = [
        .squat, .lunge, .hinge, .kneeFlexion, .kneeExtension, .hipAbduction, .hipAdduction, .calfRaise
    ]

    public static func draft(for name: String) -> UserExerciseDraft {
        let words = " " + SearchText.fold(name)
        let rule = rules.first { $0.keywords.contains(where: { contains(words, $0) }) }
        let pattern = rule?.pattern ?? .horizontalPush
        let isAssisted = contains(words, "assiste")
        let equipment = isAssisted ? .machine : equipment(in: words)
        return UserExerciseDraft(
            name: name, primaryMuscle: rule?.muscle ?? .chest, secondaryMuscles: [], equipment: equipment, pattern: pattern,
            region: region(of: pattern), loadKind: isAssisted ? .assisted : (equipment == .bodyweight ? .bodyweight : .external),
            isUnilateral: ["un bras", "unilateral", "une jambe", "single"].contains { contains(words, $0) }, needsReview: true)
    }

    /// Un mot-clé compte quand il commence un mot du nom (« abdo » trouve « abdominaux », « lateral » pas « unilateral »).
    private static func contains(_ words: String, _ keyword: String) -> Bool {
        words.contains(" " + keyword)
    }

    private static func equipment(in words: String) -> Equipment {
        equipmentRules.first { $0.keywords.contains(where: { contains(words, $0) }) }?.equipment ?? .machine
    }

    private static func region(of pattern: MovementPattern) -> BodyRegion {
        if lowerPatterns.contains(pattern) { return .lower }
        return pattern == .coreFlexion || pattern == .coreStability ? .core : .upper
    }
}
