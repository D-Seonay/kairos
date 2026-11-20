import Foundation
import PulseDomain
import PulseServices
import SupplementsFeature
import TrainFeature

/// Tout ce dont la séance en direct a besoin du dehors : le service de la séance en cours, l'environnement de l'onglet Séance
/// (bibliothèque en mode choix, fiche d'un exercice), l'autorisation des notifications, les compléments du récap et l'horloge.
public struct LiveSessionEnvironment: Sendable {
    public var service: ActiveSessionService
    public var train: TrainEnvironment
    public var notifications: any NotificationAuthorizing
    /// Les compléments « autour de la séance » du récap ; `nil` pour une séance saisie après coup, et dans les tests.
    public var supplements: SupplementsEnvironment?
    public var calendar: Calendar
    public var now: @Sendable () -> Date

    public init(service: ActiveSessionService, train: TrainEnvironment, notifications: any NotificationAuthorizing,
                supplements: SupplementsEnvironment? = nil, calendar: Calendar, now: @escaping @Sendable () -> Date) {
        self.service = service
        self.train = train
        self.notifications = notifications
        self.supplements = supplements
        self.calendar = calendar
        self.now = now
    }
}
