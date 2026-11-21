import Foundation
import Observation
import PulseDomain
import PulseServices

/// L'état de la page Profil (spec M7 §13) : le résumé (identité, série, score, records, vitrine) et le poids.
@MainActor
@Observable
public final class ProfileModel {
    public private(set) var summary: ProfileSummary?
    public private(set) var body: BodyOverview?
    public private(set) var errorMessage: String?
    public private(set) var hasLoaded = false

    @ObservationIgnored let environment: ProfileEnvironment
    /// Prévient l'app qu'un réglage a réécrit le profil (thème, prénom) ; appelé par les écrans poussés depuis la page.
    @ObservationIgnored let onProfileSaved: @MainActor (UserProfile) -> Void
    @ObservationIgnored private var isLoading = false

    public init(environment: ProfileEnvironment, onProfileSaved: @escaping @MainActor (UserProfile) -> Void) {
        self.environment = environment
        self.onProfileSaved = onProfileSaved
    }

    /// Relit le résumé et le poids. Un appel pendant une lecture est ignoré ; si la lecture échoue, la page garde son dernier
    /// état et affiche une erreur.
    public func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            async let summary = environment.profile.summary()
            async let body = environment.body.overview()
            // Les deux ou rien : la page ne mélange pas une lecture neuve et une ancienne.
            (self.summary, self.body) = try await (summary, body)
            errorMessage = nil
        } catch {
            errorMessage = String(localized: "Pulse n'a pas pu lire ton profil.", bundle: .module)
        }
        hasLoaded = true
    }
}
