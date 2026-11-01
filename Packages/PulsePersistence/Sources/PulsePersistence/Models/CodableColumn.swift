import Foundation

/// Stocke un tableau ou une structure `Codable` dans une colonne `Data?` (JSON), sans relation SwiftData.
enum CodableColumn {
    static func encode<T: Encodable>(_ value: T) -> Data? {
        try? JSONEncoder().encode(value)
    }

    static func decode<T: Decodable>(_ type: T.Type, from data: Data?, default fallback: T) -> T {
        guard let data, let value = try? JSONDecoder().decode(type, from: data) else { return fallback }
        return value
    }
}

extension RawRepresentable where RawValue == String {
    /// Relit une énumération stockée en texte, avec repli si la valeur est inconnue.
    static func stored(_ raw: String, default fallback: Self) -> Self {
        Self(rawValue: raw) ?? fallback
    }
}
