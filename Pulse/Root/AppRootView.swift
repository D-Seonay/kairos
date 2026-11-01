import OnboardingFeature
import PulseDesignSystem
import SwiftUI

/// La racine : écran de chargement, onboarding tant que le profil n'est pas terminé, puis les onglets. Toujours en sombre.
struct AppRootView: View {
    @State private var model: AppRootModel

    init(dependencies: AppDependencies) {
        _model = State(initialValue: AppRootModel(dependencies: dependencies))
    }

    var body: some View {
        content
            .preferredColorScheme(.dark)
            .tint(Color(PulsePalette.accent(for: model.theme).accent))
            .environment(\.pulseTheme, model.theme)
            .task { await model.load() }
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
                        if finished { model.onboardingFinished() }
                    }
            }
        case .main:
            if let today = model.today {
                MainTabView(dependencies: model.dependencies, today: today, firstName: model.profile?.firstName) {
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
