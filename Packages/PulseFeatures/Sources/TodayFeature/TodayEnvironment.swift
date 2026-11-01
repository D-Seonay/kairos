import Foundation
import PulseContent
import PulseDomain
import PulseServices

/// Tout ce dont l'accueil a besoin du dehors : profil, programme, nuits lues, score du jour, contenu et horloge.
public struct TodayEnvironment: Sendable {
    public var profiles: any ProfileRepository
    public var programs: any ProgramRepository
    public var nightHistory: NightHistory
    public var scores: DailyScoreService
    public var library: ContentLibrary
    public var calendar: Calendar
    public var now: @Sendable () -> Date

    public init(profiles: any ProfileRepository, programs: any ProgramRepository, nightHistory: NightHistory,
                scores: DailyScoreService, library: ContentLibrary, calendar: Calendar, now: @escaping @Sendable () -> Date) {
        self.profiles = profiles
        self.programs = programs
        self.nightHistory = nightHistory
        self.scores = scores
        self.library = library
        self.calendar = calendar
        self.now = now
    }
}
