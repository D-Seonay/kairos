import Foundation
import PulseDomain

/// Le fichier JSON de l'instantané du jour, dans le conteneur du groupe d'apps que l'app et l'extension partagent.
/// Il ne contient que ce que `WidgetSnapshot` porte : jamais une valeur de santé brute.
public struct WidgetSnapshotFile: Sendable {
    public static let appGroupIdentifier = "group.fr.seonay.pulse"
    public static let fileName = "recovery-widget.json"

    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    /// `nil` quand l'appareil ne donne pas accès au groupe d'apps (tests, signature sans le groupe).
    public static func appGroup(fileManager: FileManager = .default) -> WidgetSnapshotFile? {
        fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
            .map { WidgetSnapshotFile(url: $0.appendingPathComponent(fileName)) }
    }

    /// `nil` pour un fichier absent ou illisible : le widget montre alors « Score pas encore prêt ».
    public func read() -> WidgetSnapshot? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? Self.decoder().decode(WidgetSnapshot.self, from: data)
    }

    /// Rend `false` sans réécrire quand le fichier contient déjà cet instantané : le widget n'a pas à se recharger.
    @discardableResult
    public func write(_ snapshot: WidgetSnapshot) throws -> Bool {
        let data = try Self.encoder().encode(snapshot)
        if let existing = try? Data(contentsOf: url), existing == data { return false }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
        return true
    }

    /// Un fichier déjà absent n'est pas une erreur.
    public func delete() throws {
        do {
            try FileManager.default.removeItem(at: url)
        } catch let error as CocoaError where error.code == .fileNoSuchFile {
            return
        }
    }

    /// Clés triées : le même instantané donne toujours les mêmes octets.
    private static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
