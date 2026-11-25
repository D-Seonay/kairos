import Foundation

/// Ce qu'un rapport de diagnostic MetricKit raconte, lu dans son JSON (`MXDiagnosticPayload.jsonRepresentation()`) : combien de
/// plantages, de blocages et de lancements lents, la version de l'app et d'iOS, et la fin de la période couverte. Le rapport ne
/// porte que des piles d'appels et des métadonnées de l'appareil ; aucune donnée Santé n'y entre.
public struct DiagnosticReportSummary: Sendable, Equatable {
    public var crashes: Int
    public var hangs: Int
    public var slowLaunches: Int
    /// Les exceptions de processeur et d'écriture disque : rares, gardées sans détail.
    public var otherExceptions: Int
    /// « 1.0.4 (7) », lu dans le premier diagnostic qui la donne.
    public var appVersion: String?
    /// « iPhone OS 26.1 (23B85) », tel que MetricKit l'écrit.
    public var osVersion: String?
    /// La fin de la période couverte par le rapport ; `nil` quand la date ne se lit pas.
    public var periodEnd: Date?
    /// La raison du premier plantage (« Namespace SIGNAL, Code 0xb »), sinon son signal.
    public var crashReason: String?
    /// Le plus long blocage du rapport, en secondes.
    public var longestHangSeconds: Double?
    /// Le plus long lancement lent du rapport, en secondes.
    public var longestLaunchSeconds: Double?

    public init(crashes: Int = 0, hangs: Int = 0, slowLaunches: Int = 0, otherExceptions: Int = 0, appVersion: String? = nil,
                osVersion: String? = nil, periodEnd: Date? = nil, crashReason: String? = nil, longestHangSeconds: Double? = nil,
                longestLaunchSeconds: Double? = nil) {
        self.crashes = crashes
        self.hangs = hangs
        self.slowLaunches = slowLaunches
        self.otherExceptions = otherExceptions
        self.appVersion = appVersion
        self.osVersion = osVersion
        self.periodEnd = periodEnd
        self.crashReason = crashReason
        self.longestHangSeconds = longestHangSeconds
        self.longestLaunchSeconds = longestLaunchSeconds
    }

    /// Le nombre de diagnostics du rapport, toutes sortes confondues ; zéro pour un rapport vide.
    public var total: Int { crashes + hangs + slowLaunches + otherExceptions }

    /// `nil` quand les octets ne sont pas un objet JSON. Une clé absente ou d'un type inattendu compte pour rien : le format de
    /// MetricKit peut gagner des champs d'une version d'iOS à l'autre.
    public init?(json: Data) {
        guard let root = (try? JSONSerialization.jsonObject(with: json)) as? [String: Any] else { return nil }
        let crashes = Self.diagnostics(root["crashDiagnostics"])
        let hangs = Self.diagnostics(root["hangDiagnostics"])
        let launches = Self.diagnostics(root["appLaunchDiagnostics"])
        let others = Self.diagnostics(root["cpuExceptionDiagnostics"]) + Self.diagnostics(root["diskWriteExceptionDiagnostics"])
        let all = crashes + hangs + launches + others
        self.init(crashes: crashes.count, hangs: hangs.count, slowLaunches: launches.count, otherExceptions: others.count)
        appVersion = all.lazy.compactMap(Self.appVersion).first
        osVersion = all.lazy.compactMap { $0["osVersion"] as? String }.first
        periodEnd = (root["timeStampEnd"] as? String).flatMap(Self.date)
        crashReason = crashes.first.flatMap(Self.crashReason)
        longestHangSeconds = hangs.compactMap { ($0["hangDuration"] as? String).flatMap(Self.seconds) }.max()
        longestLaunchSeconds = launches.compactMap { ($0["launchDuration"] as? String).flatMap(Self.seconds) }.max()
    }

    // MARK: - Lecture

    /// Les métadonnées (`diagnosticMetaData`) de chaque diagnostic d'une liste.
    private static func diagnostics(_ value: Any?) -> [[String: Any]] {
        guard let list = value as? [[String: Any]] else { return [] }
        return list.map { $0["diagnosticMetaData"] as? [String: Any] ?? [:] }
    }

    private static func appVersion(_ metadata: [String: Any]) -> String? {
        guard let version = metadata["appVersion"] as? String else { return nil }
        guard let build = metadata["appBuildVersion"] as? String, !build.isEmpty else { return version }
        return "\(version) (\(build))"
    }

    private static func crashReason(_ metadata: [String: Any]) -> String? {
        if let reason = metadata["terminationReason"] as? String, !reason.isEmpty { return reason }
        if let signal = metadata["signal"] as? Int { return "Signal \(signal)" }
        return nil
    }

    /// « 3.5 sec », « 8000 ms », « 1.2 min » : la durée en secondes ; `nil` pour une unité inconnue.
    static func seconds(_ text: String) -> Double? {
        let parts = text.split(separator: " ", omittingEmptySubsequences: true)
        guard parts.count == 2, let value = Double(parts[0]) else { return nil }
        switch parts[1].lowercased() {
        case "ms": return value / 1000
        case "s", "sec", "secs", "second", "seconds": return value
        case "min", "mins", "minute", "minutes": return value * 60
        default: return nil
        }
    }

    /// MetricKit écrit « 2026-11-24 09:30:00 », dans le fuseau de l'iPhone ; une date ISO 8601 se lit aussi.
    static func date(_ text: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        if let date = formatter.date(from: text) { return date }
        return try? Date(text, strategy: .iso8601)
    }
}
