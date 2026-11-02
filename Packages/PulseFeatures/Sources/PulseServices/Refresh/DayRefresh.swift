import Foundation
import PulseDomain

/// Ce que le rafraîchissement du jour a lu et décidé, pour l'écran d'accueil.
public struct DayRefresh: Sendable, Equatable {
    public var profile: UserProfile?
    public var nights: [NightSample]
    /// L'instant de la lecture Apple Santé qui a produit `nights` ; nul si elle a échoué (les nuits viennent alors du cache).
    public var readAt: Date?
    public var plannedDay: PlannedDay
    /// Nul si le calcul du score a échoué.
    public var score: TodayScore?
    public var session: TodaySession
    /// Le check-in du jour, quand le score en est estimé.
    public var checkIn: CheckIn?

    public init(profile: UserProfile?, nights: [NightSample], readAt: Date?, plannedDay: PlannedDay, score: TodayScore?,
                session: TodaySession, checkIn: CheckIn?) {
        self.profile = profile
        self.nights = nights
        self.readAt = readAt
        self.plannedDay = plannedDay
        self.score = score
        self.session = session
        self.checkIn = checkIn
    }

    /// Un rafraîchissement qui n'a rien lu : ni nuits, ni programme, ni score.
    static func empty(profile: UserProfile?) -> DayRefresh {
        DayRefresh(profile: profile, nights: [], readAt: nil, plannedDay: .noProgram, score: nil,
                   session: TodaySession(plannedDay: .noProgram, recovery: nil), checkIn: nil)
    }
}
