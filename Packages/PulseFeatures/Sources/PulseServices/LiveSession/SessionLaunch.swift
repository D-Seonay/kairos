import Foundation
import PulseDomain
import PulseRecoveryEngine

/// Ce qu'il faut démarrer : une routine avec les ajustements du jour, ou une séance libre.
public struct SessionLaunch: Sendable, Equatable {
    public var title: String
    /// Le jour à faire, ajusté ou non ; `nil` pour une séance libre.
    public var day: RoutineDay?
    /// Le jour tel que prévu avant les ajustements de la catégorie : il sert à dire ce que le jour a changé.
    public var plannedDay: RoutineDay?
    public var programID: UUID?
    public var applied: [SessionAdjustment]
    public var refused: [SessionAdjustment]
    public var policy: ProgressionPolicy

    public init(title: String, day: RoutineDay?, plannedDay: RoutineDay? = nil, programID: UUID? = nil,
                applied: [SessionAdjustment] = [], refused: [SessionAdjustment] = [], policy: ProgressionPolicy) {
        self.title = title
        self.day = day
        self.plannedDay = plannedDay
        self.programID = programID
        self.applied = applied
        self.refused = refused
        self.policy = policy
    }

    /// Avec un score et l'adaptation activée, le jour est ajusté par la catégorie. « Séance d'origine » (ou le surmenage,
    /// qui n'a pas d'autre séance) démarre le jour prévu et refuse les ajustements de la catégorie.
    public static func routine(_ day: RoutineDay, programID: UUID?, recovery: DailyRecovery?, originalChosen: Bool,
                               profile: UserProfile?) -> SessionLaunch {
        let adaptationEnabled = profile?.adaptationEnabled ?? true
        let overreached = recovery?.category == .overreached
        let policy = ProgressionPolicy.make(recovery: recovery, adaptationEnabled: adaptationEnabled,
                                            startsOriginalAfterOverreach: overreached)
        guard adaptationEnabled, let recovery else {
            return SessionLaunch(title: day.name, day: day, plannedDay: day, programID: programID, policy: policy)
        }
        let adjusted = SessionAdjuster.adjust(day, category: recovery.category)
        if originalChosen || overreached {
            return SessionLaunch(title: day.name, day: day, plannedDay: day, programID: programID,
                                 refused: adjusted.adjustments, policy: policy)
        }
        return SessionLaunch(title: day.name, day: adjusted.day, plannedDay: day, programID: programID,
                             applied: adjusted.adjustments, policy: policy)
    }

    public static func free(policy: ProgressionPolicy) -> SessionLaunch {
        SessionLaunch(title: String(localized: "Séance libre", bundle: .module), day: nil, policy: policy)
    }
}
