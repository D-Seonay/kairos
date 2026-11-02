import LiveSessionFeature
import PulseDesignSystem
import PulseServices
import SwiftUI
import TodayFeature
import TrainFeature

/// Les cinq onglets de l'app. « Aujourd'hui », « Séance » et « Profil » ont du contenu en M4a. La séance en direct s'ouvre
/// en plein écran par-dessus ; une séance en cours qui n'est pas à l'écran garde le bandeau « Reprendre la séance » en haut.
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
    @Bindable var liveSession: LiveSessionCoordinator
    let firstName: String?
    /// Appelé après une suppression totale réussie depuis l'écran « Données ».
    let onErased: () async -> Void

    var body: some View {
        VStack(spacing: 0) {
            if let session = liveSession.current, !liveSession.isPresented {
                ResumeSessionBar(title: session.title, startedAt: session.startedAt, onResume: liveSession.resume,
                                 onAbandon: { Task { await liveSession.abandonFromBanner() } })
                    .padding(.horizontal, PulseMetrics.spacing)
                    .padding(.bottom, 8)
            }
            tabs
        }
        .background(PulsePalette.background)
        .fullScreenCover(isPresented: $liveSession.isPresented, onDismiss: refreshTabs) {
            FinishFlow(model: liveSession.model(), onFinished: liveSession.didFinish)
                .alert(liveSession.notice ?? "", isPresented: isShowingNotice) {
                    Button(String(localized: "OK")) { liveSession.dismissNotice() }
                }
        }
        // Une séance démarrée, terminée ou abandonnée change la carte de l'accueil et le haut de l'onglet Séance.
        .onChange(of: liveSession.current?.id) { refreshTabs() }
        .alert(liveSession.errorMessage ?? "", isPresented: isShowingError) {
            Button(String(localized: "OK")) { liveSession.dismissError() }
        }
    }

    private var tabs: some View {
        TabView(selection: $router.selectedTab) {
            Tab(String(localized: "Aujourd'hui"), systemImage: "sun.max", value: Item.today) {
                TodayView(model: today, onOpenProfile: { router.selectedTab = .profile }, onStartSession: start,
                          onResumeSession: liveSession.resume)
            }
            Tab(String(localized: "Planning"), systemImage: "calendar", value: Item.planning) {
                comingSoon(String(localized: "Planning"), milestone: "M6")
            }
            Tab(String(localized: "Séance"), systemImage: "dumbbell", value: Item.session) {
                TrainView(model: train, onOpenToday: { router.selectedTab = .today }, onStartSession: start,
                          onResumeSession: liveSession.resume)
            }
            Tab(String(localized: "Stats"), systemImage: "chart.bar", value: Item.stats) {
                comingSoon(String(localized: "Stats"), milestone: "M7")
            }
            Tab(String(localized: "Profil"), systemImage: "person.crop.circle", value: Item.profile) {
                ProfileHubView(dependencies: dependencies, firstName: firstName, onErased: onErased)
            }
        }
    }

    /// Démarre la séance, ou présente celle déjà en cours (le coordinateur ne démarre jamais une seconde séance).
    private func start(_ launch: SessionLaunch) {
        Task { await liveSession.start(launch) }
    }

    private func refreshTabs() {
        Task {
            await today.refresh()
            await train.refresh()
        }
    }

    private var isShowingNotice: Binding<Bool> {
        Binding(get: { liveSession.notice != nil }, set: { if !$0 { liveSession.dismissNotice() } })
    }

    private var isShowingError: Binding<Bool> {
        Binding(get: { liveSession.errorMessage != nil }, set: { if !$0 { liveSession.dismissError() } })
    }

    private func comingSoon(_ title: String, milestone: String) -> some View {
        ComingSoonView(title: title, milestone: milestone)
            .background(PulsePalette.background)
    }
}
