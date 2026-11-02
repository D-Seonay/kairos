import Foundation
import PulseContent
import PulseDomain
import PulseServices

/// Tout ce dont l'accueil a besoin du dehors : le rafraîchisseur du jour (profil, programme, nuits, score), les séances enregistrées,
/// le contenu et l'horloge.
public struct TodayEnvironment: Sendable {
    public var refresher: DayRefresher
    public var workouts: any WorkoutRepository
    public var library: ContentLibrary
    public var calendar: Calendar
    public var now: @Sendable () -> Date

    public init(refresher: DayRefresher, workouts: any WorkoutRepository, library: ContentLibrary, calendar: Calendar,
                now: @escaping @Sendable () -> Date) {
        self.refresher = refresher
        self.workouts = workouts
        self.library = library
        self.calendar = calendar
        self.now = now
    }
}
