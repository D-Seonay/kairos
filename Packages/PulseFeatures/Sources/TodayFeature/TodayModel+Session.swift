import Foundation
import PulseDomain
import PulseServices

/// Une feuille ouverte depuis la carte « Séance du jour ».
public enum TodaySheet: Identifiable, Equatable {
    case mobility

    public var id: String {
        switch self {
        case .mobility: "mobility"
        }
    }
}

extension TodayModel {
    /// Ce que « Démarrer la séance » lance : le jour ajusté, ou le jour prévu quand `startsOriginal` (« Séance d'origine »,
    /// « Démarrer quand même ») avec les ajustements de la catégorie refusés. `nil` hors d'une carte de musculation à démarrer
    /// (mobilité ou repos, course, repos, sans programme, séance faite ou en cours).
    public func sessionLaunch(startsOriginal: Bool) -> SessionLaunch? {
        guard case .strength = card, let day = session?.originalDay else { return nil }
        return SessionLaunch.routine(day, programID: profile?.activeProgramID, recovery: scoredToday,
                                     originalChosen: startsOriginal, profile: profile)
    }

    /// La séance telle que la carte la montre : l'originale si elle a été rétablie, l'ajustée sinon.
    func shownSessionLaunch() -> SessionLaunch? {
        sessionLaunch(startsOriginal: session?.status == .restored)
    }

    /// Ouvre les 20 min de mobilité. Rien n'est enregistré.
    public func startMobility() {
        sheet = .mobility
    }
}
