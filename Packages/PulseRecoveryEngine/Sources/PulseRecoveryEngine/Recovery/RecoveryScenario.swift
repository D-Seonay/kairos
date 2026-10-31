import Foundation
import PulseDomain

/// Un scénario de récupération rejouable : historique, nuit du jour et résultat attendu.
/// Partagé entre les tests du moteur et le fournisseur Apple Santé factice (spec §12).
public struct RecoveryScenario: Codable, Sendable {
    public struct Expected: Codable, Sendable {
        /// `"measured"` ou `"needsCheckIn"`.
        public var outcome: String
        public var category: RecoveryCategory?
        public var score: Double?
        /// `"ready"` ou `"calibrating:N"`.
        public var calibration: String?
        public var missing: [Factor]
    }

    public var name: String
    public var day: Date
    public var history: [NightSample]
    public var today: NightSample
    public var expected: Expected

    /// Fuseau dans lequel les dates `"YYYY-MM-DD"` des fixtures sont interprétées, à minuit.
    public static let timeZone = TimeZone(identifier: "Europe/Paris") ?? .current

    /// Décodeur acceptant les dates au format `"YYYY-MM-DD"`, décodées à minuit Europe/Paris.
    public static var decoder: JSONDecoder {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let text = try container.decode(String.self)
            guard let date = formatter.date(from: text) else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Date attendue au format YYYY-MM-DD : \(text)")
            }
            return date
        }
        return decoder
    }

    public enum LoadError: Error, Equatable {
        case notFound(String)
    }

    /// Charge `Fixtures/<name>.json` depuis le bundle donné.
    public static func load(named name: String, from bundle: Bundle) throws -> RecoveryScenario {
        guard let url = bundle.url(forResource: name, withExtension: "json", subdirectory: "Fixtures")
            ?? bundle.url(forResource: name, withExtension: "json") else {
            throw LoadError.notFound(name)
        }
        return try decoder.decode(RecoveryScenario.self, from: Data(contentsOf: url))
    }
}
