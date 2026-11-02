import Foundation
import LiveSessionFeature
import Observation
import OnboardingFeature
import PulseDomain
import PulseServices
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
    }

    private(set) var destination: Destination = .loading
    /// Le profil enregistré, lu au chargement ; il donne l'ambiance de l'app.
    private(set) var profile: UserProfile?
    private(set) var onboarding: OnboardingModel?
    private(set) var today: TodayModel?
    private(set) var train: TrainModel?
    /// La séance en direct des onglets : le bandeau « Reprendre la séance » et l'écran en plein écran.
    private(set) var liveSession: LiveSessionCoordinator?

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

    func load() async {
        #if DEBUG
        await dependencies.applyLaunchSeed()
        #endif
        await resolve()
        await refreshLiveSession()
    }

    /// Au retour au premier plan : la séance en cours, puis « Aujourd'hui », puis « Séance », qui relit le score du jour
    /// qu'« Aujourd'hui » vient d'enregistrer.
    func becameActive() async {
        guard destination == .main, let today else { return }
        let train = train
        await refreshLiveSession()
        await today.refresh()
        await train?.refresh()
    }

    /// Relit la séance en cours (les boutons de la Live Activity ont pu la changer) et ferme les Live Activities qui ne
    /// correspondent plus à aucune séance en cours (spec M4 §15.3).
    func refreshLiveSession() async {
        await liveSession?.refresh()
        // Lue au service, pas au coordinateur : un démarrage en cours y passe d'abord, et son activité n'est pas fermée.
        let current = await dependencies.liveSession.current()
        await dependencies.sessionActivity.endAll(except: current?.id)
    }

    /// L'onboarding a enregistré le profil terminé : on passe aux onglets et on relit le profil pour l'ambiance.
    func onboardingFinished() {
        show(.main)
        // L'onboarding vient de demander l'accès à Apple Santé : les observateurs lancés au démarrage, avant, ont échoué.
        dependencies.backgroundDelivery?.restart()
        Task { await reloadProfile() }
    }

    /// Après une suppression totale réussie, plus aucun profil : retour à l'onboarding, sans séance, sans Live Activity ni
    /// notification de repos (spec M4 §16).
    func dataErased() async {
        await dependencies.liveSession.discardAfterErase()
        await resolve()
    }

    private func resolve() async {
        await reloadProfile()
        show(LaunchDestination.resolve(profile: profile) == .main ? .main : .onboarding)
    }

    private func reloadProfile() async {
        profile = try? await dependencies.profiles.load()
    }

    private func show(_ next: Destination) {
        switch next {
        case .loading:
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
                let liveSession = LiveSessionCoordinator(environment: dependencies.liveSessionEnvironment())
                self.liveSession = liveSession
                sessionIntents?.coordinator = liveSession
            }
        }
        destination = next
    }

    private func dropMainModels() {
        today = nil
        train = nil
        liveSession = nil
        sessionIntents?.coordinator = nil
    }
}
