import Foundation
import os
import PulseDomain

/// Stocke un tableau ou une structure `Codable` dans une colonne `Data?` (JSON), sans relation SwiftData.
enum CodableColumn {
    /// Les types dont une colonne illisible a déjà été journalisée : une ligne abîmée est relue à chaque rafraîchissement
    /// d'écran, une seule entrée par type et par lancement suffit pour la retrouver dans les journaux.
    private static let reportedUnreadable = OSAllocatedUnfairLock(initialState: Set<String>())

    static func encode<T: Encodable>(_ value: T) -> Data? {
        logger.attempt("Colonne JSON non encodée") { try JSONEncoder().encode(value) }
    }

    static func decode<T: Decodable>(_ type: T.Type, from data: Data?, default fallback: T) -> T {
        guard let data else { return fallback }
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            let name = String(describing: type)
            if reportedUnreadable.withLock({ $0.insert(name).inserted }) {
                logger.failure("Colonne JSON illisible", error)
            }
            return fallback
        }
    }
}

extension RawRepresentable where RawValue == String {
    /// Relit une énumération stockée en texte, avec repli si la valeur est inconnue.
    static func stored(_ raw: String, default fallback: Self) -> Self {
        Self(rawValue: raw) ?? fallback
    }
}
