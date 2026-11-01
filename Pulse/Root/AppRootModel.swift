import Foundation
import Observation
import OnboardingFeature
import PulseDomain
import PulseServices
import TodayFeature

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

    let dependencies: AppDependencies

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
    }

    var theme: Theme {
        profile?.theme ?? .amber
    }

    func load() async {
        await resolve()
    }

    /// L'onboarding a enregistré le profil terminé : on passe aux onglets et on relit le profil pour l'ambiance.
    func onboardingFinished() {
        show(.main)
        Task { await reloadProfile() }
    }

    /// Après une suppression totale réussie, plus aucun profil : retour à l'onboarding.
    func dataErased() async {
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
            today = nil
        case .onboarding:
            today = nil
            onboarding = OnboardingModel(environment: dependencies.onboardingEnvironment())
        case .main:
            onboarding = nil
            if destination != .main || today == nil {
                today = TodayModel(environment: dependencies.todayEnvironment())
            }
        }
        destination = next
    }
}
