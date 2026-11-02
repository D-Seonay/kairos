import Foundation

/// Un exercice du contenu embarqué (spec M2 §4.1). Reste dans le bundle, jamais copié dans SwiftData.
public struct Exercise: Sendable, Equatable, Codable, Identifiable {
    public var id: String
    public var name: LocalizedText
    public var primaryMuscles: [Muscle]
    public var secondaryMuscles: [Muscle]
    public var equipment: Equipment
    public var pattern: MovementPattern
    public var region: BodyRegion
    public var isCompound: Bool
    public var isUnilateral: Bool
    public var loadKind: LoadKind
    public var defaultIncrementKg: Double
    public var defaultRestSeconds: Int
    public var cues: LocalizedList
    public var mistakes: LocalizedList
    public var alternatives: [String]
    /// Zones douloureuses pour lesquelles l'exercice est déconseillé ; vide quand le catalogue ne le précise pas.
    public var riskAreas: [PainArea]
    /// Exercice chronométré (gainage, planche) : la série se note en secondes, pas en répétitions.
    public var tracksDuration: Bool
    /// Un exercice retiré n'est plus proposé mais reste résoluble par les anciennes séries.
    public var retired: Bool

    public init(id: String, name: LocalizedText, primaryMuscles: [Muscle], secondaryMuscles: [Muscle],
                equipment: Equipment, pattern: MovementPattern, region: BodyRegion, isCompound: Bool,
                isUnilateral: Bool, loadKind: LoadKind, defaultIncrementKg: Double, defaultRestSeconds: Int,
                cues: LocalizedList, mistakes: LocalizedList, alternatives: [String], riskAreas: [PainArea] = [],
                tracksDuration: Bool = false, retired: Bool = false) {
        self.id = id
        self.name = name
        self.primaryMuscles = primaryMuscles
        self.secondaryMuscles = secondaryMuscles
        self.equipment = equipment
        self.pattern = pattern
        self.region = region
        self.isCompound = isCompound
        self.isUnilateral = isUnilateral
        self.loadKind = loadKind
        self.defaultIncrementKg = defaultIncrementKg
        self.defaultRestSeconds = defaultRestSeconds
        self.cues = cues
        self.mistakes = mistakes
        self.alternatives = alternatives
        self.riskAreas = riskAreas
        self.tracksDuration = tracksDuration
        self.retired = retired
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(LocalizedText.self, forKey: .name)
        primaryMuscles = try container.decode([Muscle].self, forKey: .primaryMuscles)
        secondaryMuscles = try container.decode([Muscle].self, forKey: .secondaryMuscles)
        equipment = try container.decode(Equipment.self, forKey: .equipment)
        pattern = try container.decode(MovementPattern.self, forKey: .pattern)
        region = try container.decode(BodyRegion.self, forKey: .region)
        isCompound = try container.decode(Bool.self, forKey: .isCompound)
        isUnilateral = try container.decode(Bool.self, forKey: .isUnilateral)
        loadKind = try container.decode(LoadKind.self, forKey: .loadKind)
        defaultIncrementKg = try container.decode(Double.self, forKey: .defaultIncrementKg)
        defaultRestSeconds = try container.decode(Int.self, forKey: .defaultRestSeconds)
        cues = try container.decode(LocalizedList.self, forKey: .cues)
        mistakes = try container.decode(LocalizedList.self, forKey: .mistakes)
        alternatives = try container.decode([String].self, forKey: .alternatives)
        riskAreas = try container.decodeIfPresent([PainArea].self, forKey: .riskAreas) ?? []
        tracksDuration = try container.decodeIfPresent(Bool.self, forKey: .tracksDuration) ?? false
        retired = try container.decodeIfPresent(Bool.self, forKey: .retired) ?? false
    }
}

/// Le fichier `exercises.json` entier.
public struct ExerciseCatalog: Sendable, Equatable, Codable {
    public var schemaVersion: Int
    public var contentVersion: String
    public var exercises: [Exercise]

    public init(schemaVersion: Int, contentVersion: String, exercises: [Exercise]) {
        self.schemaVersion = schemaVersion
        self.contentVersion = contentVersion
        self.exercises = exercises
    }
}
