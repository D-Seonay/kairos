import Observation
import PulseDomain

/// L'onglet affiché, que choisissent l'utilisateur, un lien du widget ou la notification du matin.
@MainActor
@Observable
final class AppRouter {
    var selectedTab: MainTabView.Item = .today

    func open(_ link: AppLink) {
        switch link {
        case .today: selectedTab = .today
        }
    }
}
