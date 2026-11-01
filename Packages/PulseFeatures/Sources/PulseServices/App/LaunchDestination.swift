import Foundation
import PulseDomain

/// Où l'app s'ouvre : l'accueil tant que l'onboarding n'est pas terminé, les onglets ensuite.
public enum LaunchDestination: Sendable, Equatable {
    case onboarding
    case main

    public static func resolve(profile: UserProfile?) -> LaunchDestination {
        profile?.onboardingCompletedAt != nil ? .main : .onboarding
    }
}
