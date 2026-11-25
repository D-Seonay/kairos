import Foundation

/// Un rapport de diagnostic gardé sur l'iPhone : son fichier JSON, tel que MetricKit l'a livré, et ce qu'il raconte.
public struct DiagnosticReport: Sendable, Equatable, Identifiable {
    /// Le nom du fichier, unique.
    public var id: String { fileURL.lastPathComponent }
    /// Le JSON du rapport, partagé tel quel par la feuille de partage.
    public let fileURL: URL
    /// L'heure où l'app a reçu le rapport, lue dans le nom du fichier.
    public let receivedAt: Date
    public let summary: DiagnosticReportSummary

    public init(fileURL: URL, receivedAt: Date, summary: DiagnosticReportSummary) {
        self.fileURL = fileURL
        self.receivedAt = receivedAt
        self.summary = summary
    }
}

/// Les derniers rapports de diagnostic MetricKit (plantages, blocages, lancements lents), gardés dans un dossier de l'iPhone :
/// jamais dans SwiftData ni dans iCloud, exclus de la sauvegarde, et jamais envoyés. L'utilisateur les lit dans l'écran
/// Diagnostic et décide de les partager. Au-delà de `limit`, les plus anciens sont supprimés, ceux sans plantage d'abord : un
/// plantage est le plus utile à l'assistance. Avant l'écriture, les textes libres du rapport sont retirés
/// (`DiagnosticReportSanitizer`).
///
/// Un fichier par rapport : `pulse-diagnostic-<aaaammjj-hhmmssmmm UTC>-<8 caractères>.json`. Le nom porte l'heure de réception,
/// et l'ordre des noms est celui des réceptions ; aucune date de fichier n'est lue.
public actor DiagnosticReportStore {
    public static let defaultLimit = 10
    static let prefix = "pulse-diagnostic-"
    static let suffix = ".json"

    private let directory: URL
    private let limit: Int
    private let now: @Sendable () -> Date

    public init(directory: URL, limit: Int = DiagnosticReportStore.defaultLimit, now: @escaping @Sendable () -> Date = { Date() }) {
        self.directory = directory
        self.limit = max(1, limit)
        self.now = now
    }

    /// Garde le JSON d'un rapport et supprime les plus anciens au-delà de la limite. `nil` pour un JSON illisible ou un rapport
    /// sans aucun diagnostic : rien n'est écrit.
    @discardableResult
    public func save(_ json: Data) throws -> DiagnosticReport? {
        guard let cleaned = DiagnosticReportSanitizer.sanitized(json), let summary = DiagnosticReportSummary(json: cleaned),
              summary.total > 0 else { return nil }
        try prepareDirectory()
        let receivedAt = now()
        let suffix = UUID().uuidString.prefix(8).lowercased()
        let url = directory.appendingPathComponent("\(Self.prefix)\(Self.stamp(receivedAt))-\(suffix)\(Self.suffix)")
        try cleaned.write(to: url, options: .atomic)
        prune()
        return DiagnosticReport(fileURL: url, receivedAt: Self.receivedAt(of: url) ?? receivedAt, summary: summary)
    }

    /// Les rapports gardés, du plus récent au plus ancien. Un fichier illisible est passé.
    public func reports() -> [DiagnosticReport] {
        reportFiles().prefix(limit).compactMap { url in
            guard let data = try? Data(contentsOf: url), let summary = DiagnosticReportSummary(json: data),
                  let receivedAt = Self.receivedAt(of: url) else { return nil }
            return DiagnosticReport(fileURL: url, receivedAt: receivedAt, summary: summary)
        }
    }

    /// Supprime tous les rapports gardés ; les autres fichiers du dossier ne sont pas touchés.
    public func removeAll() throws {
        for url in reportFiles() {
            try FileManager.default.removeItem(at: url)
        }
    }

    // MARK: - Fichiers

    /// Au-delà de la limite, garde les plus récents des rapports avec plantage, puis les plus récents des autres ; un fichier
    /// illisible part en premier.
    private func prune() {
        let files = reportFiles()
        guard files.count > limit else { return }
        // `files` va du plus récent au plus ancien : un tri stable par rang garde cet ordre dans chaque rang.
        let ranked = files.map { url -> (url: URL, rank: Int) in
            let summary = (try? Data(contentsOf: url)).flatMap(DiagnosticReportSummary.init(json:))
            return (url, summary.map { $0.crashes > 0 ? 0 : 1 } ?? 2)
        }
        let kept = Set([0, 1, 2].flatMap { rank in ranked.filter { $0.rank == rank }.map(\.url) }.prefix(limit))
        for url in files where !kept.contains(url) {
            try? FileManager.default.removeItem(at: url)
        }
    }

    /// Les fichiers de rapport du dossier, du plus récent au plus ancien (ordre inverse des noms).
    private func reportFiles() -> [URL] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        return names
            .filter { $0.hasPrefix(Self.prefix) && $0.hasSuffix(Self.suffix) }
            .sorted(by: >)
            .map { directory.appendingPathComponent($0) }
    }

    /// Crée le dossier s'il manque et pose l'exclusion des sauvegardes à chaque écriture : les rapports restent sur cet iPhone.
    private func prepareDirectory() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var url = directory
        try url.setResourceValues(values)
    }

    private static func formatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .gmt
        formatter.dateFormat = "yyyyMMdd-HHmmssSSS"
        return formatter
    }

    static func stamp(_ date: Date) -> String {
        formatter().string(from: date)
    }

    /// L'heure lue dans le nom du fichier ; `nil` pour un nom qui ne suit pas le format.
    static func receivedAt(of url: URL) -> Date? {
        let name = url.lastPathComponent
        guard name.hasPrefix(prefix) else { return nil }
        let stamp = name.dropFirst(prefix.count).prefix("yyyyMMdd-HHmmssSSS".count)
        return formatter().date(from: String(stamp))
    }
}
