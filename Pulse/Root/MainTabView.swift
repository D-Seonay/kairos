import LiveSessionFeature
import PulseDesignSystem
import PulseServices
import SupplementsFeature
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
    /// La saisie d'une séance passée, ouverte depuis l'onglet Séance.
    @Bindable var pastSession: PastSessionCoordinator
    let supplements: SupplementsModel
    let firstName: String?
    /// Appelé après une suppression totale réussie depuis l'écran « Données ».
    let onErased: () async -> Void

    var body: some View {
        VStack(spacing: 0) {
            if let session = liveSession.current, !liveSession.isPresented {
                ResumeSessionBar(title: session.title, startedAt: session.startedAt, onResume: resume,
                                 onAbandon: { Task { await liveSession.abandonFromBanner() } })
                    .padding(.horizontal, PulseMetrics.spacing)
                    .padding(.bottom, 8)
            }
            tabs
        }
        .background(PulsePalette.background)
        .fullScreenCover(isPresented: $liveSession.isPresented, onDismiss: refreshTabs) {
            FinishFlow(model: liveSession.model(), flow: liveSession.finishFlow())
                .alert(liveSession.notice ?? "", isPresented: isShowingNotice) {
                    Button(String(localized: "OK")) { liveSession.dismissNotice() }
                }
        }
        // Une séance démarrée, terminée ou abandonnée change la carte de l'accueil et le haut de l'onglet Séance.
        .onChange(of: liveSession.current?.id) { refreshTabs() }
        // L'action « Pris » d'un rappel a enregistré une prise pendant que l'app tournait.
        .onChange(of: router.supplementsVersion) { Task { await supplements.load() } }
        .alert(liveSession.errorMessage ?? "", isPresented: isShowingError) {
            Button(String(localized: "OK")) { liveSession.dismissError() }
        }
    }

    private var tabs: some View {
        TabView(selection: $router.selectedTab) {
            Tab(String(localized: "Aujourd'hui"), systemImage: "sun.max", value: Item.today) {
                TodayView(model: today, supplements: supplements, showsSupplements: $router.isShowingSupplements,
                          onOpenProfile: { router.selectedTab = .profile }, onStartSession: start, onResumeSession: resume)
            }
            Tab(String(localized: "Planning"), systemImage: "calendar", value: Item.planning) {
                comingSoon(String(localized: "Planning"), milestone: "M6")
            }
            Tab(String(localized: "Séance"), systemImage: "dumbbell", value: Item.session) {
                TrainView(model: train, onOpenToday: { router.selectedTab = .today }, onStartSession: start,
                          onResumeSession: resume, onEnterPastSession: enterPastSession)
            }
            Tab(String(localized: "Stats"), systemImage: "chart.bar", value: Item.stats) {
                comingSoon(String(localized: "Stats"), milestone: "M7")
            }
            Tab(String(localized: "Profil"), systemImage: "person.crop.circle", value: Item.profile) {
                ProfileHubView(dependencies: dependencies, supplements: supplements, firstName: firstName, onErased: onErased)
            }
        }
        // La barre d'onglets se replie quand on descend : le contenu et l'action ancrée de l'accueil gagnent de la place.
        .tabBarMinimizeBehavior(.onScrollDown)
        // Sur les onglets plutôt qu'à côté de la séance en direct : deux plein écrans sur la même vue se gênent.
        .fullScreenCover(isPresented: $pastSession.isPresented, onDismiss: refreshTabs) {
            FinishFlow(model: pastSession.model(), flow: pastSession.finishFlow())
        }
        .alert(pastSession.errorMessage ?? "", isPresented: isShowingPastError) {
            Button(String(localized: "OK")) { pastSession.dismissError() }
        }
    }

    /// Démarre la séance, ou présente celle déjà en cours (le coordinateur ne démarre jamais une seconde séance).
    private func start(_ launch: SessionLaunch) {
        Task { await liveSession.start(launch) }
    }

    /// Ouvre la saisie de la séance passée rendue par le formulaire de l'onglet Séance.
    private func enterPastSession(_ launch: SessionLaunch) {
        Task { await pastSession.start(launch) }
    }

    /// Rouvre la séance en cours, sur l'alerte de la séance oubliée si elle est restée ouverte plus de 3 h.
    private func resume() {
        Task { await liveSession.resume() }
    }

    private func refreshTabs() {
        Task {
            await today.refresh()
            await train.refresh()
            // Une séance finie place le rappel « après la séance » et peut changer les jours d'entraînement.
            await supplements.load()
            await dependencies.supplementService.rescheduleReminders()
        }
    }

    private var isShowingNotice: Binding<Bool> {
        Binding(get: { liveSession.notice != nil }, set: { if !$0 { liveSession.dismissNotice() } })
    }

    private var isShowingPastError: Binding<Bool> {
        Binding(get: { pastSession.errorMessage != nil }, set: { if !$0 { pastSession.dismissError() } })
    }

    private var isShowingError: Binding<Bool> {
        Binding(get: { liveSession.errorMessage != nil }, set: { if !$0 { liveSession.dismissError() } })
    }

    private func comingSoon(_ title: String, milestone: String) -> some View {
        ComingSoonView(title: title, milestone: milestone)
            .pulseScreenBackground(aura: 0.4)
    }
}
