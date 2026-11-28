import Foundation
import os

/// Les journaux de Pulse : un `Logger` par module, tous sous le sous-système de l'app (identifiant du bundle). Ils servent à
/// comprendre un rapport de bug quand une lecture Apple Santé, une écriture SwiftData ou une notification échoue sans bruit.
/// Aucune valeur de santé n'y entre : le contexte est un texte fixe, l'erreur est privée.
public enum PulseLog {
    /// L'identifiant de l'app, quand le code tourne hors d'un bundle (tests des packages).
    static let fallbackSubsystem = "fr.seonay.pulse"

    public static let subsystem = Bundle.main.bundleIdentifier ?? fallbackSubsystem

    /// Le journal d'un module (`persistence`, `health`, `notifications`…).
    public static func logger(_ category: String) -> Logger {
        Logger(subsystem: subsystem, category: category)
    }
}

extension Logger {
    /// Journalise une erreur rattrapée. `context` est un texte fixe qui dit ce qui a échoué ; le domaine et le code de l'erreur
    /// sont publics (ce ne sont pas des valeurs), sa description reste privée car elle peut citer une donnée.
    public func failure(_ context: String, _ failure: any Error) {
        let error = failure as NSError
        self.error("""
            \(context, privacy: .public) [\(error.domain, privacy: .public) \(error.code, privacy: .public)] \
            \(String(describing: failure), privacy: .private)
            """)
    }

    /// `try?` qui journalise : rend la valeur, ou `nil` après avoir noté l'erreur. Le repli reste celui de l'appelant.
    public func attempt<T>(_ context: String, _ body: () throws -> T) -> T? {
        do {
            return try body()
        } catch {
            failure(context, error)
            return nil
        }
    }
}
