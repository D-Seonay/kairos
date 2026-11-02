import Foundation

/// Les liens que l'app sait ouvrir : `fr.seonay.pulse://today` mène à l'accueil.
public enum AppLink: String, Sendable {
    case today

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
