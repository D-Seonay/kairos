import AppIntents
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
        .description("Ouvre immédiatement la séance du jour dans Pulse.")
    }
}

/// Intention d'ouverture immédiate de la séance du jour.
struct LaunchTodaySessionIntent: AppIntent {
    static let title: LocalizedStringResource = "Démarrer la séance"
    static let description = IntentDescription("Ouvre Pulse directement sur la séance du jour.")
    static let openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        .result()
    }
}
