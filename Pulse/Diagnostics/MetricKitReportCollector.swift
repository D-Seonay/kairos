import Foundation
import MetricKit
import PulsePersistence

extension AppDependencies {
    /// Le seul dépôt des rapports de diagnostic : le collecteur y écrit, l'écran Diagnostic le lit. Dans Application Support,
    /// exclu de la sauvegarde par le dépôt ; jamais dans SwiftData ni dans iCloud.
    static let diagnosticReports = DiagnosticReportStore(
        directory: URL.applicationSupportDirectory.appending(path: "Pulse/Diagnostics", directoryHint: .isDirectory))
}

/// Reçoit les rapports de diagnostic de MetricKit (plantages, blocages, lancements lents, au plus une fois par jour) et les garde
/// sur l'iPhone. Rien n'est envoyé : l'utilisateur les voit dans l'écran Diagnostic et choisit de les partager. Les rapports de
/// mesures quotidiennes (`MXMetricPayload`) ne sont pas demandés.
final class MetricKitReportCollector: NSObject, MXMetricManagerSubscriber, Sendable {
    private let store: DiagnosticReportStore

    init(store: DiagnosticReportStore = AppDependencies.diagnosticReports) {
        self.store = store
    }

    /// Au lancement : MetricKit livre ensuite les rapports en attente.
    func start() {
        MXMetricManager.shared.add(self)
    }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        let reports = payloads.map { $0.jsonRepresentation() }
        let store = store
        Task {
            for json in reports {
                // Un rapport qui ne s'écrit pas (disque plein) est perdu : ce n'est qu'un diagnostic.
                _ = try? await store.save(json)
            }
        }
    }
}
