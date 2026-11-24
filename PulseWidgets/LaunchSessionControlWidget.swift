import AppIntents
import Foundation
import PulseDomain
import SwiftUI
import WidgetKit

/// Widget de contrôle iOS 18 pour le Centre de Contrôle, l'écran verrouillé et le Bouton Action :
/// permet de lancer directement la séance du jour.
struct LaunchSessionControlWidget: ControlWidget {
    static let kind = "fr.seonay.pulse.LaunchSessionControl"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: LaunchTodaySessionIntent()) {
                Label("Séance du jour", systemImage: "dumbbell.fill")
            }
        }
        .displayName("Séance du jour")
        .description("Lance la séance du jour dans Pulse, ou rouvre celle en cours.")
    }
}

/// Ouvre Pulse sur le lien `start-session` : l'accueil lance la séance du jour, ou rouvre celle en cours. Un jour sans
/// musculation à lancer, l'accueil reste affiché.
struct LaunchTodaySessionIntent: AppIntent {
    static let title: LocalizedStringResource = "Démarrer la séance"
    static let description = IntentDescription("Ouvre Pulse et lance la séance du jour.")

    func perform() async throws -> some IntentResult & OpensIntent {
        guard let url = AppLink.startSession.url else { throw URLError(.badURL) }
        return .result(opensIntent: OpenURLIntent(url))
    }
}
