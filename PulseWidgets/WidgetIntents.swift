import AppIntents
import PulseLiveActivity

/// Les intentions de la Live Activity, déclarées aussi par l'extension pour que ses boutons les retrouvent ; elles s'exécutent
/// dans l'app (`SessionIntentWiring`).
struct PulseWidgetIntents: AppIntentsPackage {
    static var includedPackages: [any AppIntentsPackage.Type] {
        [PulseLiveActivityIntents.self]
    }
}
