import Observation
import PulseDomain

/// L'onglet affiché, que choisissent l'utilisateur, un lien du widget ou une notification ; l'écran Compléments, qu'ouvre un
/// rappel touché ; l'écran Photos de corps, qu'ouvre le rappel de photos ; et un compteur qui change quand l'action « Pris »
/// d'un rappel a enregistré une prise. Un lien vers l'accueil referme l'écran qui y était poussé ; le contrôle « Séance du
/// jour » demande en plus de lancer la séance du jour.
@MainActor
@Observable
final class AppRouter {
    var selectedTab: MainTabView.Item = .today
    var isShowingSupplements = false
    private(set) var supplementsVersion = 0
    /// Change à chaque lien vers l'accueil : l'écran « Pourquoi » poussé se referme.
    private(set) var todayRootVersion = 0
    /// Change à chaque demande de lancement de la séance du jour ; `pendingSessionStart` dit si elle reste à traiter.
    private(set) var sessionStartRequests = 0
    /// Vrai tant que la demande du contrôle « Séance du jour » n'a pas été traitée par les onglets (au lancement à froid, ils
    /// n'existent pas encore).
    var pendingSessionStart = false
    /// Vrai quand un rappel de photos touché demande l'écran Photos de corps : l'onglet Profil y va, puis le remet à faux.
    var opensBodyPhotos = false

    func open(_ link: AppLink) {
        switch link {
        case .today: showTodayRoot()
        case .supplements:
            selectedTab = .today
            isShowingSupplements = true
        case .planning: selectedTab = .planning
        case .bodyPhotos:
            selectedTab = .profile
            opensBodyPhotos = true
        case .startSession:
            showTodayRoot()
            pendingSessionStart = true
            sessionStartRequests += 1
        }
    }

    /// Une prise vient d'être enregistrée hors de l'écran : les vues des compléments se relisent.
    func supplementsChanged() {
        supplementsVersion += 1
    }

    /// L'accueil lui-même : l'onglet, sans l'écran Compléments ni l'écran « Pourquoi » poussés.
    private func showTodayRoot() {
        selectedTab = .today
        isShowingSupplements = false
        todayRootVersion += 1
    }
}
