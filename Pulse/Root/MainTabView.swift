import LiveSessionFeature
import PlanningFeature
import ProfileFeature
import PulseDesignSystem
import PulseDomain
import PulseServices
import RunFeature
import StatsFeature
import StoreKit
import SupplementsFeature
import SwiftUI
import TodayFeature
import TrainFeature

/// Les cinq onglets de l'app. La séance en direct et la course s'ouvrent en plein écran par-dessus ; une séance en cours qui n'est
/// pas à l'écran garde « Reprendre la séance » dans l'accessoire de la barre d'onglets (iOS 26.1, en haut avant), une course son
/// bandeau « Reprendre » en haut.
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
    /// La course : l'écran de départ, de course et de récap, le bandeau et les alertes de reprise et d'oubli.
    @Bindable var run: RunCoordinator
    /// La saisie d'une séance passée, ouverte depuis l'onglet Séance.
    @Bindable var pastSession: PastSessionCoordinator
    let supplements: SupplementsModel
    /// Appelé après une suppression totale réussie depuis « Mes données » (ou l'écran de debug « Données »).
    let onErased: () async -> Void
    /// Vrai pendant l'enregistrement ou la suppression d'une course interrompue : l'alerte ne revient pas en attendant.
    @State private var isAnsweringRecovery = false
    /// « Abandonner » de l'accessoire « Reprendre la séance », en attente de confirmation.
    @State private var confirmsAbandon = false
    /// La demande de note, faite une fois l'écran de séance fermé.
    @Environment(\.requestReview) private var requestReview

    var body: some View {
        // La course a son plein écran sur une vue à part : deux plein écrans sur la même vue se gênent.
        ZStack {
            tabsLayer
        }
        .fullScreenCover(isPresented: $run.isPresented, onDismiss: refreshTabs) {
            RunFlowView(model: run.model())
                .alert(forgottenTitle, isPresented: isShowingForgotten) {
                    forgottenActions
                }
                .alert(run.errorMessage ?? "", isPresented: isShowingRunError(presented: true)) {
                    Button(String(localized: "OK")) { run.errorMessage = nil }
                }
        }
        .alert(recoveryTitle, isPresented: isShowingRecovery) {
            recoveryActions
        }
        .alert(run.errorMessage ?? "", isPresented: isShowingRunError(presented: false)) {
            Button(String(localized: "OK")) { run.errorMessage = nil }
        }
    }

    /// Les bandeaux « Reprendre », les onglets et le plein écran de la séance en direct.
    private var tabsLayer: some View {
        VStack(spacing: 0) {
            if !Self.usesResumeAccessory, let session = liveSession.current, !liveSession.isPresented {
                ResumeSessionBar(title: session.title, startedAt: session.startedAt, onResume: resume,
                                 onAbandon: { Task { await liveSession.abandonFromBanner() } })
                    .padding(.horizontal, PulseMetrics.spacing)
                    .padding(.bottom, 8)
            }
            if let snapshot = run.current, !run.isPresented {
                ResumeRunBar(snapshot: snapshot, onResume: { Task { await run.resume() } })
                    .padding(.horizontal, PulseMetrics.spacing)
                    .padding(.bottom, 8)
            }
            tabs
        }
        .background(PulsePalette.background)
        .fullScreenCover(isPresented: $liveSession.isPresented, onDismiss: liveSessionClosed) {
            FinishFlow(model: liveSession.model(), flow: liveSession.finishFlow())
                .alert(liveSession.notice ?? "", isPresented: isShowingNotice) {
                    Button(String(localized: "OK")) { liveSession.dismissNotice() }
                }
        }
        // Une séance démarrée, terminée ou abandonnée change la carte de l'accueil et le haut de l'onglet Séance.
        .onChange(of: liveSession.current?.id) { refreshTabs() }
        // L'action « Pris » d'un rappel a enregistré une prise pendant que l'app tournait.
        .onChange(of: router.supplementsVersion) { Task { await supplements.load() } }
        // Un lien du widget ou du contrôle vers l'accueil referme l'écran « Pourquoi » poussé.
        .onChange(of: router.todayRootVersion) { today.closeWhy() }
        // Le contrôle « Séance du jour » : traité dès que les onglets sont là, au lancement à froid compris.
        .task(id: router.sessionStartRequests) { await startPendingSession() }
        .alert(liveSession.errorMessage ?? "", isPresented: isShowingError) {
            Button(String(localized: "OK")) { liveSession.dismissError() }
        }
        .confirmationDialog(String(localized: "Abandonner la séance ?"), isPresented: $confirmsAbandon, titleVisibility: .visible) {
            Button(String(localized: "Abandonner"), role: .destructive) { Task { await liveSession.abandonFromBanner() } }
            Button(String(localized: "Continuer la séance"), role: .cancel) {}
        } message: {
            Text(String(localized: "Les séries validées sont gardées, les autres ne sont pas enregistrées."))
        }
    }

    /// L'accessoire de la barre d'onglets n'existe qu'à partir d'iOS 26.1 (`isEnabled`) : avant, le bandeau reste en haut.
    private static var usesResumeAccessory: Bool {
        if #available(iOS 26.1, *) { true } else { false }
    }

    /// « Reprendre la séance » sous les onglets, pour une séance en cours qui n'est pas à l'écran.
    @ViewBuilder
    private var resumeAccessory: some View {
        if let session = liveSession.current {
            ResumeSessionAccessory(title: session.title, startedAt: session.startedAt, onResume: resume,
                                   onAbandon: { confirmsAbandon = true })
        }
    }

    private var tabs: some View {
        TabView(selection: $router.selectedTab) {
            Tab(String(localized: "Aujourd'hui"), systemImage: "sun.max", value: Item.today) {
                TodayView(model: today, supplements: supplements, showsSupplements: $router.isShowingSupplements,
                          onOpenProfile: { router.selectedTab = .profile }, onStartSession: start, onResumeSession: resume,
                          onStartRun: startRun, onCreateRoutine: { router.selectedTab = .session })
            }
            Tab(String(localized: "Planning"), systemImage: "calendar", value: Item.planning) {
                PlanningView(model: planning, train: train, onStartSession: start, onResumeSession: resume,
                             onStartRun: startRun, onPlanChanged: planChanged)
            }
            Tab(String(localized: "Séance"), systemImage: "dumbbell", value: Item.session) {
                TrainView(model: train, onOpenToday: { router.selectedTab = .today }, onStartSession: start,
                          onResumeSession: resume, onEnterPastSession: enterPastSession, onStartRun: startRun)
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
        // Au-dessus de la barre, et dans la barre quand elle se replie : la séance se reprend sans remonter en haut de l'écran.
        .resumeSessionAccessory(isEnabled: liveSession.current != nil && !liveSession.isPresented) { resumeAccessory }
        // Sur les onglets plutôt qu'à côté de la séance en direct : deux plein écrans sur la même vue se gênent.
        .fullScreenCover(isPresented: $pastSession.isPresented, onDismiss: refreshTabs) {
            FinishFlow(model: pastSession.model(), flow: pastSession.finishFlow())
        }
        .alert(pastSession.errorMessage ?? "", isPresented: isShowingPastError) {
            Button(String(localized: "OK")) { pastSession.dismissError() }
        }
    }

    /// Démarre la séance, ou présente celle déjà en cours (le coordinateur ne démarre jamais une seconde séance). Une course en
    /// cours l'empêche : une seule activité à la fois.
    private func start(_ launch: SessionLaunch) {
        guard run.current == nil else {
            run.errorMessage = String(localized: "Une course est en cours.")
            return
        }
        Task { await liveSession.start(launch) }
    }

    /// Le contrôle « Séance du jour » : rouvre la séance en cours, sinon relit l'accueil et lance la séance du jour telle que la
    /// carte la montre. Un jour sans musculation à lancer (repos, course, séance faite), l'accueil reste simplement affiché.
    private func startPendingSession() async {
        guard router.pendingSessionStart else { return }
        router.pendingSessionStart = false
        if liveSession.current == nil {
            // Une lecture déjà en cours (lancement à froid, retour au premier plan) fait revenir `refresh()` tout de suite : on
            // l'attend, quelques secondes au plus.
            await today.refresh()
            var waits = 0
            while today.isLoading, waits < 50 {
                try? await Task.sleep(for: .milliseconds(100))
                waits += 1
            }
        }
        if liveSession.current != nil {
            resume()
        } else if let launch = today.shownSessionLaunch() {
            start(launch)
        }
    }

    /// Ouvre l'écran de départ de la course, ou celui de la course déjà en cours.
    private func startRun(_ launch: RunLaunch) {
        run.prepare(launch)
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
            eraseConfirmation: { onErased in AnyView(EraseSheet(dependencies: dependencies, onErased: onErased)) })
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

    /// Un déplacement dans le planning change la séance du jour et les jours d'entraînement : l'accueil et les rappels de
    /// compléments suivent (le planning et la séance se relisent eux-mêmes).
    private func planChanged() {
        Task {
            await today.refresh()
            await supplements.load()
            await dependencies.supplementService.rescheduleReminders()
        }
    }

    /// L'écran de séance s'est fermé : les onglets se relisent, puis la demande de note du récap, s'il en a voulu une, une
    /// seconde plus tard, quand plus rien ne s'anime (StoreKit ignore une demande faite pendant la fermeture d'un plein écran).
    /// iOS décide encore d'afficher ou non la fenêtre : jamais sur TestFlight, trois fois par an au plus sur l'App Store.
    private func liveSessionClosed() {
        refreshTabs()
        guard liveSession.takePendingReview() else { return }
        Task {
            try? await Task.sleep(for: .seconds(1))
            requestReview()
        }
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

    // MARK: Course

    /// « Course interrompue : enregistrer 4,2 km jusqu'à 7 h 52 ? » (spec V2a §5.4).
    private var recoveryTitle: String {
        run.recovery.map { RunText.recoveryMessage($0, calendar: dependencies.calendar) } ?? ""
    }

    @ViewBuilder
    private var recoveryActions: some View {
        Button(String(localized: "Enregistrer")) { answerRecovery { await run.saveInterruptedRun() } }
            .keyboardShortcut(.defaultAction)
        Button(String(localized: "Supprimer"), role: .destructive) { answerRecovery { await run.discardInterruptedRun() } }
    }

    private func answerRecovery(_ action: @escaping @MainActor () async -> Void) {
        isAnsweringRecovery = true
        Task {
            await action()
            isAnsweringRecovery = false
        }
    }

    /// « Course toujours en cours ? Pulse peut la terminer à 7 h 52, ton dernier déplacement. »
    private var forgottenTitle: String {
        run.forgottenEnd.map { RunText.forgottenMessage($0, calendar: dependencies.calendar) } ?? ""
    }

    @ViewBuilder
    private var forgottenActions: some View {
        if let end = run.forgottenEnd {
            let time = RunText.clock(end, calendar: dependencies.calendar)
            Button(String(localized: "Terminer à \(time)")) { Task { await run.finishAtForgottenEnd() } }
                .keyboardShortcut(.defaultAction)
            Button(String(localized: "Continuer"), role: .cancel) { run.dismissForgotten() }
        }
    }

    // L'alerte de reprise attend la réponse du coordinateur, et celle d'oubli se résout dans son bouton (« Terminer » lit l'heure
    // proposée après la fermeture) : une fermeture sans bouton ne change rien. Un enregistrement en échec montre son erreur
    // d'abord, puis l'alerte de reprise revient.
    private var isShowingRecovery: Binding<Bool> {
        Binding(get: { run.recovery != nil && !run.isPresented && !isAnsweringRecovery && run.errorMessage == nil },
                set: { _ in })
    }

    private var isShowingForgotten: Binding<Bool> {
        Binding(get: { run.forgottenEnd != nil }, set: { _ in })
    }

    /// L'erreur de la course s'affiche sur l'écran de course quand il est ouvert, sur les onglets sinon.
    private func isShowingRunError(presented: Bool) -> Binding<Bool> {
        Binding(get: { run.errorMessage != nil && run.isPresented == presented },
                set: { if !$0 { run.errorMessage = nil } })
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

private extension View {
    /// `tabViewBottomAccessory(isEnabled:)` à partir d'iOS 26.1 ; avant, rien (le bandeau du haut reste) : la variante sans
    /// `isEnabled` d'iOS 26.0 laisserait une capsule vide sans séance en cours.
    @ViewBuilder
    func resumeSessionAccessory<Accessory: View>(isEnabled: Bool, @ViewBuilder content: () -> Accessory) -> some View {
        if #available(iOS 26.1, *) {
            tabViewBottomAccessory(isEnabled: isEnabled, content: content)
        } else {
            self
        }
    }
}
