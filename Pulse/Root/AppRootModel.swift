import Foundation
import LiveSessionFeature
import Observation
import OnboardingFeature
import PlanningFeature
import ProfileFeature
import PulseDomain
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

    init(dependencies: AppDependencies, sessionIntents: SessionIntentWiring? = nil) {
        self.dependencies = dependencies
        self.sessionIntents = sessionIntents
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

    /// Au retour au premier plan : la séance en cours, puis « Aujourd'hui », puis « Séance », qui relit le score du jour
    /// qu'« Aujourd'hui » vient d'enregistrer, puis « Planning ».
    func becameActive() async {
        // L'accès à Apple Santé a pu être accordé dans Réglages pendant que l'app était en arrière-plan.
        dependencies.backgroundDelivery?.restartIfStopped()
        guard destination == .main, let today else { return }
        let train = train
        let planning = planning
        let stats = stats
        let profileModel = profileModel
        await refreshLiveSession()
        // Une course interrompue à proposer, ou une course rattachée dont l'écran se rouvre.
        await run?.refresh()
        await today.refresh()
        await train?.refresh()
        // « Aujourd'hui » vient de lire les courses d'Apple Santé : la semaine et la série en tiennent compte.
        await planning?.load()
        await supplements?.load()
        await refreshSupplementReminders()
        // Les statistiques relisent tout l'historique : seulement une fois l'onglet ouvert (son `.task` charge la première fois).
        if let stats, stats.hasLoaded { await stats.load() }
        // Le profil lit la série, le score et le poids que le passage du jour vient de mettre à jour : en dernier, et seulement
        // une fois l'onglet ouvert, comme les statistiques.
        if let profileModel, profileModel.hasLoaded { await profileModel.load() }
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
