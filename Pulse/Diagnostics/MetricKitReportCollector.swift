import Foundation
import MetricKit
import PulsePersistence
import UIKit

extension AppDependencies {
    /// Le seul dépôt des rapports de diagnostic : le collecteur y écrit, l'écran Diagnostic le lit. Dans Application Support,
    /// exclu de la sauvegarde par le dépôt ; jamais dans SwiftData ni dans iCloud.
    static let diagnosticReports = DiagnosticReportStore(
        directory: URL.applicationSupportDirectory.appending(path: "Pulse/Diagnostics", directoryHint: .isDirectory))
}

/// Reçoit les rapports de diagnostic de MetricKit (plantages, blocages, lancements lents, livrés au lancement qui suit) et les
/// garde sur l'iPhone. Rien n'est envoyé : l'utilisateur les voit dans l'écran Diagnostic et choisit de les partager. Les rapports de
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
        Task { @MainActor in
            // Livrés juste après le lancement, l'app peut repartir en arrière-plan avant la fin de l'écriture : iOS lui laisse le
            // temps de finir.
            let background = BackgroundTask(name: "Rapports MetricKit")
            for json in reports {
                // Un rapport qui ne s'écrit pas (disque plein) est perdu : ce n'est qu'un diagnostic.
                _ = try? await store.save(json)
            }
            background.end()
        }
    }
}

/// Une tâche d'arrière-plan d'UIKit, terminée une seule fois : à la fin du travail, ou quand iOS reprend le temps accordé.
@MainActor
private final class BackgroundTask {
    private var identifier: UIBackgroundTaskIdentifier = .invalid

    init(name: String) {
        identifier = UIApplication.shared.beginBackgroundTask(withName: name) { [weak self] in
            self?.end()
        }
    }

    func end() {
        guard identifier != .invalid else { return }
        UIApplication.shared.endBackgroundTask(identifier)
        identifier = .invalid
    }
}
