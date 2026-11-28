import PulseDomain
import PulsePersistence

/// « Tout supprimer » efface aussi les rapports de diagnostic gardés sur l'iPhone, une fois le reste effacé. Un rapport qui ne
/// s'efface pas ne fait pas échouer la suppression : il ne contient aucune donnée de l'utilisateur.
struct DiagnosticReportsEraser: DataEraser {
    let inner: any DataEraser
    let reports: DiagnosticReportStore

    func eraseEverything(options: EraseOptions) async throws {
        try await inner.eraseEverything(options: options)
        do {
            try await reports.removeAll()
        } catch {
            logger.failure("Rapports de diagnostic non effacés", error)
        }
    }
}
