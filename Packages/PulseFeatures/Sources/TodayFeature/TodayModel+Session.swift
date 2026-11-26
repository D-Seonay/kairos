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
                                     originalChosen: startsOriginal, profile: profile, deload: deloadStatus)
    }

    /// La séance telle que la carte la montre : l'originale si elle a été rétablie, l'ajustée sinon. L'app la lance aussi depuis le
    /// contrôle « Séance du jour ». Tant que le check-in du jour attend, c'est la séance prévue, sans ajustement faute de score :
    /// ce que l'onglet Séance lance aussi. Le check-in reste proposé, il n'est pas un passage obligé.
    public func shownSessionLaunch() -> SessionLaunch? {
        sessionLaunch(startsOriginal: session?.status == .restored)
    }

    /// Vrai tant que le check-in du jour attend et que la carte montre une musculation à lancer : la carte offre alors
    /// « Démarrer sans check-in », qui lance `shownSessionLaunch()`.
    var canStartWithoutCheckIn: Bool {
        guard case .needsCheckIn = score, case .strength = card else { return false }
        return true
    }

    /// Ouvre les 20 min de mobilité. Rien n'est enregistré.
    public func startMobility() {
        sheet = .mobility
    }
}
