import Foundation
import Observation
import PulsePersistence

/// Les rapports de diagnostic gardés sur l'iPhone, pour l'écran Diagnostic : la liste, et leur suppression.
@MainActor
@Observable
final class DiagnosticReportsModel {
    private(set) var reports: [DiagnosticReport] = []
    private(set) var errorMessage: String?

    private let store: DiagnosticReportStore

    init(store: DiagnosticReportStore = AppDependencies.diagnosticReports) {
        self.store = store
    }

    func load() async {
        reports = await store.reports()
    }

    func removeAll() async {
        do {
            try await store.removeAll()
            errorMessage = nil
        } catch {
            errorMessage = String(localized: "Les rapports n'ont pas pu être supprimés.")
        }
        await load()
    }

    // MARK: - Textes

    /// « 1 plantage · 2 blocages · 1 lancement lent » ; les exceptions rares ferment la ligne.
    static func title(_ summary: DiagnosticReportSummary) -> String {
        var parts: [String] = []
        if summary.crashes > 0 { parts.append(String(localized: "\(summary.crashes) plantage(s)")) }
        if summary.hangs > 0 { parts.append(String(localized: "\(summary.hangs) blocage(s)")) }
        if summary.slowLaunches > 0 { parts.append(String(localized: "\(summary.slowLaunches) lancement(s) lent(s)")) }
        if summary.otherExceptions > 0 { parts.append(String(localized: "\(summary.otherExceptions) autre(s) alerte(s)")) }
        return parts.joined(separator: " · ")
    }

    /// La version, puis le plus long blocage ou lancement et la raison du plantage, quand le rapport les donne.
    static func details(_ summary: DiagnosticReportSummary) -> [String] {
        var lines: [String] = []
        if let version = summary.appVersion { lines.append(String(localized: "Pulse \(version)")) }
        if let os = summary.osVersion { lines.append(os) }
        if let reason = summary.crashReason { lines.append(String(localized: "Plantage : \(reason)")) }
        if let hang = summary.longestHangSeconds { lines.append(String(localized: "Plus long blocage : \(seconds(hang))")) }
        if let launch = summary.longestLaunchSeconds { lines.append(String(localized: "Plus long lancement : \(seconds(launch))")) }
        return lines
    }

    private static func seconds(_ value: Double) -> String {
        Duration.seconds(value).formatted(.units(allowed: [.minutes, .seconds], width: .abbreviated,
                                                 fractionalPart: .show(length: 1)))
    }
}
