import Foundation

/// Les choix de correspondance retenus aux imports Hevy précédents, par nom d'exercice de l'export.
public protocol HevyMappingStore: Sendable {
    func load() -> [String: HevyMappingChoice]
    func save(_ choices: [String: HevyMappingChoice])
}

/// Choix gardés dans `UserDefaults`, en JSON. Seul le nom de la suite est retenu : `UserDefaults` n'est pas `Sendable`.
/// La clé vit dans le domaine de la suite, que la suppression totale vide en entier.
public final class UserDefaultsHevyMappingStore: HevyMappingStore {
    static let key = "pulse.hevyMappings"

    private let suiteName: String?

    public init(suiteName: String?) {
        self.suiteName = suiteName
    }

    private var defaults: UserDefaults {
        suiteName.flatMap(UserDefaults.init(suiteName:)) ?? .standard
    }

    /// Des choix illisibles valent une table vide : l'import repropose alors ses correspondances.
    public func load() -> [String: HevyMappingChoice] {
        guard let data = defaults.data(forKey: Self.key) else { return [:] }
        return (try? JSONDecoder().decode([String: HevyMappingChoice].self, from: data)) ?? [:]
    }

    public func save(_ choices: [String: HevyMappingChoice]) {
        guard let data = try? JSONEncoder().encode(choices) else { return }
        defaults.set(data, forKey: Self.key)
    }
}
