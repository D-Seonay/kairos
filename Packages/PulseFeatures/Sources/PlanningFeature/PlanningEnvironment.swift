import Foundation
import PulseDomain
import PulseServices
import TrainFeature

/// Tout ce dont l'onglet Planning a besoin du dehors : la semaine datée, l'environnement de l'onglet Séance (pour le détail
/// d'une séance), les tracés des courses Pulse et l'horloge.
public struct PlanningEnvironment: Sendable {
    public var service: PlanningService
    public var train: TrainEnvironment
    public var calendar: Calendar
    public var now: @Sendable () -> Date
    /// Les tracés des courses faites avec Pulse, pour la section « Tracé » du détail ; `nil`, le détail n'en montre pas.
    public var tracks: (any RunTrackRepository)?

    public init(service: PlanningService, train: TrainEnvironment, calendar: Calendar, now: @escaping @Sendable () -> Date,
                tracks: (any RunTrackRepository)? = nil) {
        self.service = service
        self.train = train
        self.calendar = calendar
        self.now = now
        self.tracks = tracks
    }

    /// `date` en français, dans le calendrier de l'environnement.
    func text(of date: Date, fields: (Date.FormatStyle) -> Date.FormatStyle) -> String {
        let style = Date.FormatStyle(date: .omitted, time: .omitted, locale: Locale(identifier: "fr_FR"), calendar: calendar,
                                     timeZone: calendar.timeZone)
        return date.formatted(fields(style))
    }
}

/// Un écran poussé depuis l'onglet Planning.
public enum PlanningDestination: Hashable, Sendable {
    /// Le détail d'une séance de musculation.
    case session(UUID)
    /// Le détail d'une course ou d'un vélo lu d'Apple Santé.
    case activity(UUID)
    /// Le mois et la série.
    case month
}
