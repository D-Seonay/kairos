import Foundation
import PulseContent
import PulseServices

/// Tout ce dont l'accueil a besoin du dehors : le rafraîchisseur du jour (profil, programme, nuits, score), le contenu et l'horloge.
public struct TodayEnvironment: Sendable {
    public var refresher: DayRefresher
    public var library: ContentLibrary
    public var calendar: Calendar
    public var now: @Sendable () -> Date

    public init(refresher: DayRefresher, library: ContentLibrary, calendar: Calendar, now: @escaping @Sendable () -> Date) {
        self.refresher = refresher
        self.library = library
        self.calendar = calendar
        self.now = now
    }
}
