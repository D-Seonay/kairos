import Foundation

/// Retire d'un rapport MetricKit les champs de texte libre qu'une exception peut porter : le message composé d'une exception
/// Objective-C (`composedMessage`) et ses arguments (`arguments`), qui peuvent reprendre une valeur de l'app. Le reste (piles
/// d'appels, version, appareil, durées, raison de fin système, gabarit du message) est gardé tel quel.
public enum DiagnosticReportSanitizer {
    /// Les clés retirées partout dans le rapport, à n'importe quelle profondeur.
    static let removedKeys: Set<String> = ["composedMessage", "arguments"]

    /// Le rapport nettoyé, en JSON trié et indenté pour être lisible une fois partagé ; `nil` si ce n'est pas un objet JSON.
    public static func sanitized(_ json: Data) -> Data? {
        guard let root = (try? JSONSerialization.jsonObject(with: json)) as? [String: Any] else { return nil }
        return try? JSONSerialization.data(withJSONObject: clean(root), options: [.prettyPrinted, .sortedKeys])
    }

    private static func clean(_ value: Any) -> Any {
        if let object = value as? [String: Any] {
            var kept: [String: Any] = [:]
            for (key, child) in object where !removedKeys.contains(key) {
                kept[key] = clean(child)
            }
            return kept
        }
        if let list = value as? [Any] {
            return list.map(clean)
        }
        return value
    }
}
