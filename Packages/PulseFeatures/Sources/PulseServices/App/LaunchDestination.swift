import Foundation
import PulseDomain

/// Où l'app s'ouvre : l'accueil tant que l'onboarding n'est pas terminé, les onglets ensuite.
public enum LaunchDestination: Sendable, Equatable {
    case onboarding
    case main
    /// Le stockage n'a pas pu être ouvert, ou le profil n'a pas pu être lu : ni l'onboarding, qui ferait croire que tout est
    /// perdu et enregistrerait dans le vide, ni les onglets.
    case storageUnavailable

    public static func resolve(profile: UserProfile?) -> LaunchDestination {
        profile?.onboardingCompletedAt != nil ? .main : .onboarding
    }

    /// `storeOpened` est faux quand l'app tourne sur le magasin de secours en mémoire. Un profil en échec de lecture n'est pas
    /// un profil absent.
    public static func resolve(storeOpened: Bool, profile: Result<UserProfile?, any Error>) -> LaunchDestination {
        guard storeOpened, case .success(let profile) = profile else { return .storageUnavailable }
        return resolve(profile: profile)
    }
}
