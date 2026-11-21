import LiveSessionFeature
import PlanningFeature
import ProfileFeature
import PulseDesignSystem
import PulseServices
import StatsFeature
import SupplementsFeature
import SwiftUI
import TodayFeature
import TrainFeature

/// Les cinq onglets de l'app. La séance en direct s'ouvre en plein écran par-dessus ; une séance en cours qui n'est pas à
/// l'écran garde le bandeau « Reprendre la séance » en haut.
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
    let planning: PlanningModel
    let stats: StatsModel
    let profile: ProfileModel
    @Bindable var liveSession: LiveSessionCoordinator
    /// La saisie d'une séance passée, ouverte depuis l'onglet Séance.
    @Bindable var pastSession: PastSessionCoordinator
    let supplements: SupplementsModel
    /// Appelé après une suppression totale réussie depuis « Mes données » (ou l'écran de debug « Données »).
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
                PlanningView(model: planning, train: train, onStartSession: start, onResumeSession: resume)
            }
            Tab(String(localized: "Séance"), systemImage: "dumbbell", value: Item.session) {
                TrainView(model: train, onOpenToday: { router.selectedTab = .today }, onStartSession: start,
                          onResumeSession: resume, onEnterPastSession: enterPastSession)
            }
            Tab(String(localized: "Stats"), systemImage: "chart.bar", value: Item.stats) {
                StatsScreen(model: stats)
            }
            Tab(String(localized: "Profil"), systemImage: "person.crop.circle", value: Item.profile) {
                ProfileScreen(model: profile, supplements: supplements, screens: profileScreens,
                              onOpenStats: { router.selectedTab = .stats }, onOpenRecords: openRecords, onErased: onErased)
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

    /// « Tout voir » du mur des records : l'onglet Stats, sur la vue Records.
    private func openRecords() {
        stats.view = .records
        router.selectedTab = .stats
    }

    /// Les écrans de la cible app que l'onglet Profil pousse : le diagnostic Apple Santé (Paramètres), la confirmation de
    /// suppression et, en Debug seulement, l'écran « Données » (Mes données).
    private var profileScreens: ProfileAppScreens {
        let dependencies = dependencies
        return ProfileAppScreens(
            healthDiagnostics: {
                AnyView(HealthDiagnosticsView(model: HealthDiagnosticsModel(dependencies: dependencies, today: dependencies.now())))
            },
            dataDebug: dataDebugScreen,
            eraseConfirmation: { onErased in
                AnyView(EraseConfirmationView(model: DataDebugModel(dependencies: dependencies), onErased: onErased))
            })
    }

    /// L'écran de debug « Données » (données d'exemple, inspection des tables) n'existe pas en Release (spec M7 §16).
    private var dataDebugScreen: (() -> AnyView)? {
        #if DEBUG
        let dependencies = dependencies
        let onErased = onErased
        return { AnyView(DataDebugView(model: DataDebugModel(dependencies: dependencies), onErased: onErased)) }
        #else
        return nil
        #endif
    }

    /// Rouvre la séance en cours, sur l'alerte de la séance oubliée si elle est restée ouverte plus de 3 h.
    private func resume() {
        Task { await liveSession.resume() }
    }

    private func refreshTabs() {
        Task {
            await today.refresh()
            await train.refresh()
            await planning.load()
            // Une séance finie place le rappel « après la séance » et peut changer les jours d'entraînement.
            await supplements.load()
            await dependencies.supplementService.rescheduleReminders()
            // Les statistiques relisent tout l'historique : seulement une fois l'onglet ouvert (son `.task` charge la première fois).
            if stats.hasLoaded { await stats.load() }
            // Une séance finie change la série, le nombre de séances, les records et les badges du profil.
            if profile.hasLoaded { await profile.load() }
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
}
