import Foundation
import PulseServices

extension TodayModel {
    /// « Connecter Apple Santé » de la bannière du check-in : la demande d'accès de l'onboarding, puis l'actualisation du
    /// retour au premier plan, pour qu'un score mesuré remplace le check-in sans relancer l'app. HealthKit ne dit pas si la
    /// lecture est accordée : sans donnée lue, le check-in reste, avec la bannière « Pas de données de nuit ». Une demande qui
    /// échoue (Apple Santé indisponible) le dit sur la bannière et garde l'offre.
    public func connectHealth() async {
        guard let access = environment.healthAccess, !isConnectingHealth else { return }
        isConnectingHealth = true
        defer { isConnectingHealth = false }
        // Un second échec redit le même message : l'effacer d'abord le fait annoncer de nouveau à VoiceOver.
        healthAccessError = nil
        do {
            try await access.request()
        } catch {
            healthAccessError = String(localized: "Pulse n'a pas pu accéder à Apple Santé.", bundle: .module)
            return
        }
        healthAccessRequested = true
        await refreshAfterCurrentRead()
    }

    /// Une lecture déjà en cours fait revenir `refresh()` tout de suite, sur des données d'avant la demande : on l'attend,
    /// quelques secondes au plus, puis on relit.
    private func refreshAfterCurrentRead() async {
        var waits = 0
        while isLoading, waits < 50 {
            try? await Task.sleep(for: .milliseconds(100))
            waits += 1
        }
        await refresh()
    }
}
