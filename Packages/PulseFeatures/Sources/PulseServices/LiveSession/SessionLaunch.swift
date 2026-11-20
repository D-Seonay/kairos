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
    /// Le début et la fin d'une séance passée saisie après coup (spec M4 §19.4) ; `nil` pour une séance en direct.
    public var past: DateInterval?
    /// Le facteur des charges proposées : 0,9 pendant une semaine de décharge (spec M6 §10), 1 sinon.
    public var loadFactor: Double

    public init(title: String, day: RoutineDay?, plannedDay: RoutineDay? = nil, programID: UUID? = nil,
                applied: [SessionAdjustment] = [], refused: [SessionAdjustment] = [], policy: ProgressionPolicy,
                past: DateInterval? = nil, loadFactor: Double = 1) {
        self.title = title
        self.day = day
        self.plannedDay = plannedDay
        self.programID = programID
        self.applied = applied
        self.refused = refused
        self.policy = policy
        self.past = past
        self.loadFactor = loadFactor
    }

    /// Avec un score et l'adaptation activée, le jour est ajusté par la catégorie. « Séance d'origine » (ou le surmenage,
    /// qui n'a pas d'autre séance) démarre le jour prévu et refuse les ajustements de la catégorie. Pendant une semaine de
    /// décharge acceptée, le jour perd 40 % de ses séries avant tout le reste, ses charges baissent de 10 % et ne montent pas ;
    /// refusée, la décharge est notée parmi les ajustements refusés (spec M6 §10).
    public static func routine(_ day: RoutineDay, programID: UUID?, recovery: DailyRecovery?, originalChosen: Bool,
                               profile: UserProfile?, deload: DeloadStatus = .none) -> SessionLaunch {
        var launch = adapted(day, programID: programID, recovery: recovery, originalChosen: originalChosen, profile: profile,
                             base: deload.isActive ? DeloadAdjuster.apply(day).day : day)
        switch deload {
        case .active:
            launch.applied.insert(DeloadAdjuster.adjustment, at: 0)
            launch.policy.allowsIncrease = false
            launch.loadFactor = DeloadAdjuster.loadFactor
        case .declined:
            launch.refused.insert(DeloadAdjuster.adjustment, at: 0)
        case .none:
            break
        }
        return launch
    }

    // swiftlint:disable function_parameter_count
    /// Le lancement de `base` (le jour prévu, ou déjà allégé par la décharge) avec les ajustements de la catégorie.
    private static func adapted(_ day: RoutineDay, programID: UUID?, recovery: DailyRecovery?, originalChosen: Bool,
                                profile: UserProfile?, base: RoutineDay) -> SessionLaunch {
        let adaptationEnabled = profile?.adaptationEnabled ?? true
        let overreached = recovery?.category == .overreached
        let policy = ProgressionPolicy.make(recovery: recovery, adaptationEnabled: adaptationEnabled,
                                            startsOriginalAfterOverreach: overreached)
        guard adaptationEnabled, let recovery else {
            return SessionLaunch(title: day.name, day: base, plannedDay: day, programID: programID, policy: policy)
        }
        let adjusted = SessionAdjuster.adjust(base, category: recovery.category)
        if originalChosen || overreached {
            return SessionLaunch(title: day.name, day: base, plannedDay: day, programID: programID,
                                 refused: adjusted.adjustments, policy: policy)
        }
        return SessionLaunch(title: day.name, day: adjusted.day, plannedDay: day, programID: programID,
                             applied: adjusted.adjustments, policy: policy)
    }
    // swiftlint:enable function_parameter_count

    public static func free(policy: ProgressionPolicy) -> SessionLaunch {
        SessionLaunch(title: String(localized: "Séance libre", bundle: .module), day: nil, policy: policy)
    }

    /// Une séance passée à saisir sur `interval` : la routine telle que prévue, ou une séance vide. Le score de ce jour-là ne
    /// l'ajuste pas, et la hausse de charge reste permise (« il faut toujours progresser ») **(choix du constructeur)**.
    public static func past(_ day: RoutineDay?, programID: UUID?, interval: DateInterval) -> SessionLaunch {
        SessionLaunch(title: day?.name ?? String(localized: "Séance libre", bundle: .module), day: day, plannedDay: day,
                      programID: day == nil ? nil : programID, policy: ProgressionPolicy(allowsIncrease: true), past: interval)
    }
}
