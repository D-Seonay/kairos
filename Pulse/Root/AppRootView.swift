import OnboardingFeature
import PulseDesignSystem
import PulseDomain
import SwiftUI
import TodayFeature
import TrainFeature

/// La racine : écran de chargement, onboarding tant que le profil n'est pas terminé, puis les onglets. Toujours en sombre.
struct AppRootView: View {
    @State private var model: AppRootModel
    let router: AppRouter
    @Environment(\.scenePhase) private var scenePhase

    init(dependencies: AppDependencies, router: AppRouter, sessionIntents: SessionIntentWiring? = nil) {
        _model = State(initialValue: AppRootModel(dependencies: dependencies, sessionIntents: sessionIntents))
        self.router = router
    }

    var body: some View {
        content
            .preferredColorScheme(.dark)
            .tint(Color(PulsePalette.accent(for: model.theme).accent))
            .environment(\.pulseTheme, model.theme)
            .task { await model.load() }
            .onOpenURL { AppLink(url: $0).map(router.open) }
            .onChange(of: scenePhase) { _, phase in
                // Chaque retour au premier plan relit la séance en cours, « Aujourd'hui » et « Séance », quel que soit l'onglet.
                guard phase == .active else { return }
                Task { await model.becameActive() }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch model.destination {
        case .loading:
            LoadingView()
        case .onboarding:
            if let onboarding = model.onboarding {
                OnboardingFlowView(model: onboarding)
                    .id(ObjectIdentifier(onboarding))
                    .onChange(of: onboarding.isFinished, initial: true) { _, finished in
                        guard finished else { return }
                        // Après une suppression totale, les onglets repartent d'« Aujourd'hui ».
                        router.open(.today)
                        model.onboardingFinished()
                    }
            }
        case .main:
            if let today = model.today, let train = model.train, let liveSession = model.liveSession {
                MainTabView(dependencies: model.dependencies, router: router, today: today, train: train,
                            liveSession: liveSession, firstName: model.profile?.firstName) {
                    await model.dataErased()
                }
                .id(ObjectIdentifier(today))
            }
        }
    }
}

/// Le temps de lire le profil : le fond de l'app et un indicateur discret.
private struct LoadingView: View {
    var body: some View {
        ZStack {
            PulsePalette.background.ignoresSafeArea()
            ProgressView()
        }
    }
}
