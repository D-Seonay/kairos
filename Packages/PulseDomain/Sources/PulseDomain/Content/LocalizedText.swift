/// Un texte localisé : le français est obligatoire, l'anglais facultatif (spec M2 §4.1).
public struct LocalizedText: Sendable, Equatable, Codable {
    public var fr: String
    public var en: String?

    public init(fr: String, en: String? = nil) {
        self.fr = fr
        self.en = en
    }
}

/// Une liste de textes localisée (consignes, erreurs fréquentes).
public struct LocalizedList: Sendable, Equatable, Codable {
    public var fr: [String]
    public var en: [String]?

    public init(fr: [String], en: [String]? = nil) {
        self.fr = fr
        self.en = en
    }
}
