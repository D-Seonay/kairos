import Foundation
import PulseDomain
import PulseServices

extension TodayModel {
    /// La décharge du profil relu par l'accueil, à l'instant présent.
    var deloadStatus: DeloadStatus {
        Deload.status(profile: profile, now: environment.now(), calendar: environment.calendar)
    }

    /// Accepte ou refuse la semaine de décharge proposée, puis relit l'accueil : la séance du jour suit la décision. Une écriture
    /// refusée garde la proposition et l'erreur.
    public func decideDeload(_ accepted: Bool) async {
        do {
            try await environment.refresher.decideDeload(accepted)
            errorMessage = nil
        } catch {
            errorMessage = String(localized: "Pulse n'a pas pu enregistrer ta décision.", bundle: .module)
            return
        }
        await refresh()
    }
}
