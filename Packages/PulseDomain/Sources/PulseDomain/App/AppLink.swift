import Foundation

/// Les liens que l'app sait ouvrir : `fr.seonay.pulse://today` mène à l'accueil, `fr.seonay.pulse://supplements` à l'écran
/// Compléments, `fr.seonay.pulse://planning` à l'onglet Planning, et `fr.seonay.pulse://start-session` lance (ou rouvre) la
/// séance du jour depuis l'accueil.
public enum AppLink: String, Sendable {
    case today
    case supplements
    case planning
    case startSession = "start-session"

    public static let scheme = "fr.seonay.pulse"

    public var url: URL? {
        var components = URLComponents()
        components.scheme = Self.scheme
        components.host = rawValue
        return components.url
    }

    public init?(url: URL) {
        guard url.scheme == Self.scheme, let host = url.host, let link = AppLink(rawValue: host) else { return nil }
        self = link
    }
}
