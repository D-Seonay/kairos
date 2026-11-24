import AppIntents
import Foundation
import PulseDomain
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

/// Ouvre Pulse sur le lien `today` : l'accueil, son score et sa carte de récupération, quel que soit l'écran laissé ouvert.
struct OpenRecoveryScoreIntent: AppIntent {
    static let title: LocalizedStringResource = "Consulter la récupération"
    static let description = IntentDescription("Ouvre Pulse sur le tableau de bord de récupération.")

    func perform() async throws -> some IntentResult & OpensIntent {
        guard let url = AppLink.today.url else { throw URLError(.badURL) }
        return .result(opensIntent: OpenURLIntent(url))
    }
}
