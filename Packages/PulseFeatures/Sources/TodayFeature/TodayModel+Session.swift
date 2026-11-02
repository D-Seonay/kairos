import Foundation
import PulseDomain

/// Une feuille ouverte depuis la carte « Séance du jour ».
public enum TodaySheet: Identifiable, Equatable {
    /// La séance de musculation à suivre en salle, telle qu'elle est à faire aujourd'hui.
    case start(RoutineDay)
    case mobility

    public var id: String {
        switch self {
        case .start(let day): "start-\(day.id.uuidString)"
        case .mobility: "mobility"
        }
    }
}

extension TodayModel {
    /// Ouvre la séance de musculation affichée : l'ajustée sous le badge « Ajustée », l'originale sinon.
    /// Sans effet hors d'une carte de musculation (mobilité ou repos, course, repos, sans programme).
    public func startSession() {
        guard case .strength(let strength) = card else { return }
        let day = strength.badge == .adjusted ? session?.activeDay : session?.originalDay
        guard let day else { return }
        sheet = .start(day)
    }

    /// Ouvre les 20 min de mobilité. Rien n'est enregistré.
    public func startMobility() {
        sheet = .mobility
    }
}
