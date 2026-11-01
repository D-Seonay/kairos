import Foundation

/// Désigne un exercice du contenu (identifiant stable) ou un exercice créé par l'utilisateur (UUID). Spec M2 §5.2.
public enum ExerciseReference: Sendable, Equatable, Hashable {
    case content(id: String)
    case user(id: UUID)

    public var contentID: String? {
        if case .content(let id) = self { return id }
        return nil
    }

    public var userID: UUID? {
        if case .user(let id) = self { return id }
        return nil
    }

    /// Reconstruit la référence depuis deux colonnes ; nil si aucune ou les deux sont renseignées.
    public init?(contentID: String?, userID: UUID?) {
        switch (contentID, userID) {
        case (let content?, nil): self = .content(id: content)
        case (nil, let user?): self = .user(id: user)
        default: return nil
        }
    }
}

extension ExerciseReference: Codable {
    private enum CodingKeys: String, CodingKey {
        case content
        case user
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let content = try container.decodeIfPresent(String.self, forKey: .content) {
            self = .content(id: content)
        } else if let user = try container.decodeIfPresent(UUID.self, forKey: .user) {
            self = .user(id: user)
        } else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath,
                                                    debugDescription: "Référence d'exercice attendue : {\"content\": …} ou {\"user\": …}"))
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .content(let id): try container.encode(id, forKey: .content)
        case .user(let id): try container.encode(id, forKey: .user)
        }
    }
}
