import Foundation
import LiveSessionFeature
import Observation
import OnboardingFeature
import PlanningFeature
import ProfileFeature
import PulseDomain
import PulsePersistence
import PulseServices
import RunFeature
import StatsFeature
import SupplementsFeature
import TodayFeature
import TrainFeature

/// Où l'app en est : chargement du profil, onboarding, ou onglets. Chaque entrée dans une destination repart d'un modèle neuf.
@MainActor
@Observable
final class AppRootModel {
    enum Destination: Equatable {
        case loading
        case onboarding
        case main
        /// Le stockage n'a pas pu être ouvert ou lu : un écran qui le dit, à la place de l'onboarding.
        case storageUnavailable
    }

    private(set) var destination: Destination = .loading
    /// Le profil enregistré, lu au chargement et réécrit par les réglages ; il donne l'ambiance de l'app.
    private(set) var profile: UserProfile?
    private(set) var onboarding: OnboardingModel?
    private(set) var today: TodayModel?
    private(set) var train: TrainModel?
    /// L'onglet Planning : la semaine datée, la série et le mois.
    private(set) var planning: PlanningModel?
    /// L'onglet Stats : la charge, la biométrie, les muscles, l'assiduité et les records de la période.
    private(set) var stats: StatsModel?
    /// L'onglet Profil : le résumé, le poids, les réglages et les données stockées.
    private(set) var profileModel: ProfileModel?
    /// La séance en direct des onglets : le bandeau « Reprendre la séance » et l'écran en plein écran.
    private(set) var liveSession: LiveSessionCoordinator?
    /// La course des onglets : l'écran de course en plein écran, le bandeau « Reprendre la course » et les alertes de reprise et
    /// d'oubli.
    private(set) var run: RunCoordinator?
    /// La saisie d'une séance passée, à côté de la séance en direct.
    private(set) var pastSession: PastSessionCoordinator?
    /// Les compléments du jour, partagés par la carte de l'accueil et l'écran Compléments (accueil et profil).
    private(set) var supplements: SupplementsModel?

    let dependencies: AppDependencies
    /// Les boutons de la Live Activity relisent la séance des onglets ; `nil` dans les tests.
    private let sessionIntents: SessionIntentWiring?
    /// Décide si un retour au premier plan relit les onglets : jour changé, donnée changée, ou dernière relecture trop vieille.
    @ObservationIgnored private var reloadGate = ActivationReloadGate()
    /// Les relectures des onglets faites par un retour au premier plan, pour les tests.
    @ObservationIgnored private(set) var activationReloads = 0
    /// Prévient la porte d'un enregistrement SwiftData, d'un import iCloud ou d'un changement de fuseau.
    @ObservationIgnored private var changeObserver: DataChangeObserver?

    /// `changes` : le centre de notifications observé ; un centre à part dans les tests, que les enregistrements des autres tests
    /// ne touchent pas.
    init(dependencies: AppDependencies, sessionIntents: SessionIntentWiring? = nil, changes: NotificationCenter = .default) {
        self.dependencies = dependencies
        self.sessionIntents = sessionIntents
        changeObserver = DataChangeObserver(center: changes) { [weak self] kind in
            Task { @MainActor in self?.noteDataChange(kind) }
        }
    }

    /// Une donnée a changé hors des écrans (passage du jour en arrière-plan, action d'une notification, autre appareil, fuseau) :
    /// le prochain retour au premier plan relit les onglets. Un import iCloud ou un changement de fuseau arrivé pendant une
    /// relecture compte encore ; un enregistrement arrivé pendant une relecture est le sien.
    func noteDataChange(_ kind: DataChangeObserver.Kind = .external) {
        switch kind {
        case .save: reloadGate.noteSave()
        case .external: reloadGate.noteExternalChange()
        }
    }

    var theme: Theme {
        profile?.theme ?? .amber
    }

    /// La silhouette des cartes musculaires : celle du sexe du profil, de femme sans profil ou pour « Autre ».
    var muscleMapFigure: MuscleMapFigure {
        MuscleMapFigure(sex: profile?.sex ?? .unspecified)
    }

    func load() async {
        #if DEBUG
        await dependencies.applyLaunchSeed()
        #endif
        await start()
    }

    /// Vrai quand le magasin est ouvert mais que la lecture a échoué : relire peut suffire. Faux quand l'app tourne sur le
    /// magasin de secours en mémoire, que seule une relance de l'app remplace.
    var canRetryStorage: Bool {
        dependencies.storeError == nil
    }

    /// « Réessayer » de l'écran de stockage indisponible.
    func retryStorage() async {
        await start()
    }

    private func start() async {
        await resolve()
        // Sans stockage, aucune séance en cours n'est lisible : fermer les Live Activities « orphelines » couperait une vraie séance.
        guard destination != .storageUnavailable else { return }
        await refreshLiveSession()
        await run?.refresh()
        await refreshSupplementReminders()
    }

    /// Au retour au premier plan : toujours la séance en cours et la course (les boutons de la Live Activity ont pu les changer).
    /// Les onglets ne sont relus que si le jour a changé, si une donnée a changé hors des écrans, ou si la dernière relecture a
    /// plus de dix minutes : deux retours rapprochés (centre de notifications, widget) ne relisent qu'une fois.
    func becameActive(at date: Date? = nil) async {
        // L'accès à Apple Santé a pu être accordé dans Réglages pendant que l'app était en arrière-plan.
        dependencies.backgroundDelivery?.restartIfStopped()
        guard destination == .main, let today else { return }
        await refreshLiveSession()
        // Une course interrompue à proposer, ou une course rattachée dont l'écran se rouvre.
        await run?.refresh()
        let start = date ?? dependencies.now()
        guard reloadGate.beginReload(at: start, calendar: dependencies.calendar) else { return }
        await reloadTabs(today: today)
        reloadGate.endReload(at: start)
        activationReloads += 1
    }

    /// « Aujourd'hui », puis « Séance », qui relit le score du jour qu'« Aujourd'hui » vient d'enregistrer, en même temps que
    /// « Planning », qui tient compte des courses d'Apple Santé qu'« Aujourd'hui » vient de lire ; les compléments et les rappels
    /// à côté, indépendants. Stats et Profil, une fois leur onglet ouvert, en dernier : ils lisent ce que le passage du jour vient
    /// de mettre à jour.
    private func reloadTabs(today: TodayModel) async {
        let train = train
        let planning = planning
        let stats = stats
        let profileModel = profileModel
        let supplements = supplements
        async let supplementsReloaded: Void = reloadSupplements(supplements)
        await today.refresh()
        async let trainReloaded: Void = refresh(train)
        await planning?.load()
        await trainReloaded
        async let statsReloaded: Void = reloadIfOpened(stats)
        if let profileModel, profileModel.hasLoaded { await profileModel.load() }
        await statsReloaded
        await supplementsReloaded
    }

    private func refresh(_ train: TrainModel?) async {
        await train?.refresh()
    }

    /// Les statistiques relisent tout l'historique : seulement une fois l'onglet ouvert (son `.task` charge la première fois).
    private func reloadIfOpened(_ stats: StatsModel?) async {
        if let stats, stats.hasLoaded { await stats.load() }
    }

    private func reloadSupplements(_ supplements: SupplementsModel?) async {
        await supplements?.load()
        await refreshSupplementReminders()
    }

    /// Les rappels de compléments couvrent 14 jours : chaque lancement et chaque retour au premier plan les recalculent, et
    /// réécrivent dans Apple Santé les prises faites iPhone verrouillé (spec M5 §5, §7). Les rappels du coucher, sur sept soirs,
    /// sont recalculés au même moment. Le rappel de photos de corps, dont les trois échéances sont peut-être passées, repart de
    /// maintenant s'il est actif et que plus rien n'est en attente.
    func refreshSupplementReminders() async {
        guard destination == .main else { return }
        await dependencies.supplementService.retryHealthWrites()
        await dependencies.supplementService.rescheduleReminders()
        await dependencies.bedtimeReminderService.reschedule()
        await dependencies.checkInReminders.reschedule() // Le rappel de check-in suit les mesures de montre relues.
        await dependencies.photos.reminders.resumeIfIdle(now: dependencies.now())
    }

    /// Relit la séance en cours (les boutons de la Live Activity ont pu la changer) et ferme les Live Activities qui ne
    /// correspondent plus à aucune séance en cours (spec M4 §15.3).
    func refreshLiveSession() async {
        await liveSession?.refresh()
        // Lue au service, pas au coordinateur, en une seule opération : un démarrage en cours n'a pas son activité fermée.
        await dependencies.liveSession.closeStaleActivities()
    }

    /// L'onboarding a enregistré le profil terminé : on passe aux onglets et on relit le profil pour l'ambiance.
    func onboardingFinished() {
        show(.main)
        // L'onboarding vient de demander l'accès à Apple Santé : les observateurs lancés au démarrage, avant, ont échoué.
        dependencies.backgroundDelivery?.restart()
        Task { await reloadProfile() }
    }

    /// Après une suppression totale réussie, plus aucun profil : retour à l'onboarding, sans séance ni course, sans Live Activity
    /// ni notification de repos ou d'oubli (spec M4 §16).
    func dataErased() async {
        await dependencies.liveSession.discardAfterErase()
        // Une course en cours est abandonnée de même : son brouillon vient d'être effacé.
        await dependencies.run.service.discard()
        await resolve()
    }

    private func resolve() async {
        let loaded: Result<UserProfile?, any Error>
        do {
            loaded = .success(try await dependencies.profiles.load())
        } catch {
            loaded = .failure(error)
        }
        profile = try? loaded.get()
        switch LaunchDestination.resolve(storeOpened: dependencies.storeError == nil, profile: loaded) {
        case .main: show(.main)
        case .onboarding: show(.onboarding)
        case .storageUnavailable: show(.storageUnavailable)
        }
    }

    private func reloadProfile() async {
        profile = try? await dependencies.profiles.load()
    }

    private func show(_ next: Destination) {
        switch next {
        case .loading, .storageUnavailable:
            onboarding = nil
            dropMainModels()
        case .onboarding:
            dropMainModels()
            onboarding = OnboardingModel(environment: dependencies.onboardingEnvironment())
        case .main:
            onboarding = nil
            if destination != .main || today == nil {
                today = TodayModel(environment: dependencies.todayEnvironment())
                train = TrainModel(environment: dependencies.trainEnvironment())
                planning = PlanningModel(environment: dependencies.planningEnvironment())
                stats = StatsModel(environment: dependencies.statsEnvironment())
                // Un réglage enregistré (ambiance, prénom) s'applique tout de suite à la racine ; un nouvel objectif de sommeil
                // recalcule tout de suite le score du jour pas encore figé.
                profileModel = ProfileModel(environment: dependencies.profileEnvironment()) { [weak self] saved in
                    guard let self else { return }
                    let goalChanged = saved.sleepGoalMinutes != profile?.sleepGoalMinutes
                    profile = saved
                    guard goalChanged, let today else { return }
                    // Une lecture déjà en cours fait revenir `refresh()` tout de suite, peut-être sur l'ancien objectif : on
                    // l'attend, quelques secondes au plus, comme `MainTabView`, puis on relit.
                    Task {
                        var waits = 0
                        while today.isLoading, waits < 50 {
                            try? await Task.sleep(for: .milliseconds(100))
                            waits += 1
                        }
                        await today.refresh()
                    }
                }
                let liveSession = LiveSessionCoordinator(environment: dependencies.liveSessionEnvironment())
                self.liveSession = liveSession
                let run = RunCoordinator(environment: dependencies.runEnvironment { [weak liveSession] in
                    liveSession?.current != nil
                })
                self.run = run
                pastSession = PastSessionCoordinator(environment: dependencies.pastSessionEnvironment())
                supplements = SupplementsModel(environment: dependencies.supplementsEnvironment())
                sessionIntents?.coordinator = liveSession
                sessionIntents?.runCoordinator = run
                // Les onglets neufs se chargent eux-mêmes en s'affichant : un retour au premier plan juste après ne relit pas.
                reloadGate.endReload(at: dependencies.now())
            }
        }
        destination = next
    }

    private func dropMainModels() {
        today = nil
        train = nil
        planning = nil
        stats = nil
        profileModel = nil
        liveSession = nil
        run = nil
        pastSession = nil
        supplements = nil
        sessionIntents?.coordinator = nil
        sessionIntents?.runCoordinator = nil
    }
}
