import AppIntents
import OnboardingFeature
import PulseDesignSystem
import PulseDomain
import SwiftUI
import TodayFeature
import TrainFeature

/// La racine : écran de chargement, onboarding tant que le profil n'est pas terminé, puis les onglets ; un écran à part quand
/// le stockage est indisponible. Sur papier clair, sauf la séance en direct.
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
            // L'app est sur papier ; seule la séance en direct et son récap restent noirs (spec M4 §14.2).
            .preferredColorScheme(.light)
            .tint(Color(PulsePalette.accent(for: model.theme).accent))
            .environment(\.pulseTheme, model.theme)
            .environment(\.muscleMapFigure, model.muscleMapFigure)
            .task { await model.load() }
            .onOpenURL { AppLink(url: $0).map(router.open) }
            .onChange(of: scenePhase) { _, phase in
                // En quittant l'app, Siri reçoit les noms des compléments, peut-être modifiés, pour « J'ai pris ma créatine ».
                if phase == .background { PulseShortcuts.updateAppShortcutParameters() }
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
        case .storageUnavailable:
            StorageUnavailableView(canRetry: model.canRetryStorage) {
                await model.retryStorage()
            }
        case .onboarding:
            if let onboarding = model.onboarding {
                OnboardingFlowView(model: onboarding)
                    .id(ObjectIdentifier(onboarding))
                    .onChange(of: onboarding.isFinished, initial: true) { _, finished in
                        guard finished else { return }
                        // Après une suppression totale, les onglets repartent d'« Aujourd'hui ». Une demande « Séance du jour »,
                        // « Pourquoi » ou de course faite pendant l'onboarding est oubliée : elle ne lance rien des minutes plus tard.
                        router.dropPendingRequests()
                        router.open(.today)
                        model.onboardingFinished()
                    }
            }
        case .main:
            if let today = model.today, let train = model.train, let planning = model.planning, let stats = model.stats,
               let profile = model.profileModel, let liveSession = model.liveSession, let pastSession = model.pastSession,
               let supplements = model.supplements, let run = model.run {
                MainTabView(dependencies: model.dependencies, router: router, today: today, train: train, planning: planning,
                            stats: stats, profile: profile, liveSession: liveSession, run: run, pastSession: pastSession,
                            supplements: supplements) {
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
                .accessibilityLabel(String(localized: "Chargement"))
        }
    }
}

#if DEBUG
#Preview("Chargement, accessibilité 3") {
    LoadingView()
        .dynamicTypeSize(.accessibility3)
}
#endif
