import Observation
import PulseDomain

/// L'onglet affiché, que choisissent l'utilisateur, un lien du widget ou une notification ; l'écran Compléments, qu'ouvre un
/// rappel touché ; et un compteur qui change quand l'action « Pris » d'un rappel a enregistré une prise.
@MainActor
@Observable
final class AppRouter {
    var selectedTab: MainTabView.Item = .today
    var isShowingSupplements = false
    private(set) var supplementsVersion = 0

    func open(_ link: AppLink) {
        switch link {
        case .today: selectedTab = .today
        case .supplements:
            selectedTab = .today
            isShowingSupplements = true
        }
    }

    /// Une prise vient d'être enregistrée hors de l'écran : les vues des compléments se relisent.
    func supplementsChanged() {
        supplementsVersion += 1
    }
}
