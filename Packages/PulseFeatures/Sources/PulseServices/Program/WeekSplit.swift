import Foundation

/// Le partage de la semaine que l'onboarding tire du profil : `sessions` séances par semaine, dont `runs` sorties de course ;
/// le reste, `strength`, en musculation.
public struct WeekSplit: Sendable, Equatable {
    /// Les séances par semaine choisies : la semaine adoptée n'en compte pas plus, sauf si le modèle seul en compte déjà plus.
    public var sessions: Int
    /// Les sorties que le curseur demande, jamais plus que `sessions`.
    public var runs: Int

    /// Les séances de musculation que la semaine demande : celles que les sorties ne prennent pas.
    public var strength: Int {
        sessions - runs
    }

    public init(sessions: Int, runs: Int) {
        self.sessions = max(0, sessions)
        self.runs = min(max(0, runs), self.sessions)
    }

    /// Le partage du curseur : `round(jours × (1 − focus))` séances de musculation, le reste en sorties.
    public init(focus: Double, daysPerWeek: Int) {
        self.init(sessions: daysPerWeek, runs: RunDayPlanner.requestedRuns(focus: focus, daysPerWeek: daysPerWeek))
    }
}
