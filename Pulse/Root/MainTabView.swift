import PulseDesignSystem
import SwiftUI
import TodayFeature
import TrainFeature

/// Les cinq onglets de l'app. « Aujourd'hui », « Séance » et « Profil » ont du contenu en M4a.
struct MainTabView: View {
    enum Item: Hashable {
        case today
        case planning
        case session
        case stats
        case profile
    }

    let dependencies: AppDependencies
    /// L'onglet affiché : un lien du widget ou la notification du matin le change aussi.
    @Bindable var router: AppRouter
    let today: TodayModel
    let train: TrainModel
    let firstName: String?
    /// Appelé après une suppression totale réussie depuis l'écran « Données ».
    let onErased: () async -> Void

    var body: some View {
        TabView(selection: $router.selectedTab) {
            Tab(String(localized: "Aujourd'hui"), systemImage: "sun.max", value: Item.today) {
                // L'écran en direct n'est pas encore branché : démarrer et reprendre ne font rien jusqu'à son ouverture.
                TodayView(model: today, onOpenProfile: { router.selectedTab = .profile }, onStartSession: { _ in },
                          onResumeSession: {})
            }
            Tab(String(localized: "Planning"), systemImage: "calendar", value: Item.planning) {
                comingSoon(String(localized: "Planning"), milestone: "M6")
            }
            Tab(String(localized: "Séance"), systemImage: "dumbbell", value: Item.session) {
                TrainView(model: train) { router.selectedTab = .today }
            }
            Tab(String(localized: "Stats"), systemImage: "chart.bar", value: Item.stats) {
                comingSoon(String(localized: "Stats"), milestone: "M7")
            }
            Tab(String(localized: "Profil"), systemImage: "person.crop.circle", value: Item.profile) {
                ProfileHubView(dependencies: dependencies, firstName: firstName, onErased: onErased)
            }
        }
    }

    private func comingSoon(_ title: String, milestone: String) -> some View {
        ComingSoonView(title: title, milestone: milestone)
            .background(PulsePalette.background)
    }
}
