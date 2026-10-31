/// Catégorie du score de récupération (spec §6.5) : optimal ≥ 90, normal ≥ 65, fatigue modérée ≥ 40, surmenage sinon.
public enum RecoveryCategory: String, Sendable, Codable {
    case optimal
    case normal
    case moderateFatigue
    case overreached

    public init(score: Double) {
        if score >= 90 {
            self = .optimal
        } else if score >= 65 {
            self = .normal
        } else if score >= 40 {
            self = .moderateFatigue
        } else {
            self = .overreached
        }
    }
}
