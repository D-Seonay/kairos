import AppIntents
import SwiftUI
import WidgetKit

/// Widget de contrôle iOS 18 pour le Centre de Contrôle, l'écran verrouillé et le Bouton Action :
/// permet d'ouvrir immédiatement le score et le tableau de bord de récupération.
struct RecoveryScoreControlWidget: ControlWidget {
    static let kind = "fr.seonay.pulse.RecoveryScoreControl"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: OpenRecoveryScoreIntent()) {
                Label("Récupération", systemImage: "heart.fill")
            }
        }
        .displayName("Récupération")
        .description("Ouvre immédiatement ton tableau de bord de récupération.")
    }
}

/// Intention d'ouverture immédiate du tableau de bord de récupération.
struct OpenRecoveryScoreIntent: AppIntent {
    static let title: LocalizedStringResource = "Consulter la récupération"
    static let description = IntentDescription("Ouvre Pulse sur le tableau de bord de récupération.")
    static let openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        .result()
    }
}
