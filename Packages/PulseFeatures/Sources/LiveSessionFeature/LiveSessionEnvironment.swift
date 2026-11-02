import Foundation
import PulseDomain
import PulseServices
import TrainFeature

/// Tout ce dont la séance en direct a besoin du dehors : le service de la séance en cours, l'environnement de l'onglet Séance
/// (bibliothèque en mode choix, fiche d'un exercice), l'autorisation des notifications et l'horloge.
public struct LiveSessionEnvironment: Sendable {
    public var service: ActiveSessionService
    public var train: TrainEnvironment
    public var notifications: any NotificationAuthorizing
    public var calendar: Calendar
    public var now: @Sendable () -> Date

    public init(service: ActiveSessionService, train: TrainEnvironment, notifications: any NotificationAuthorizing,
                calendar: Calendar, now: @escaping @Sendable () -> Date) {
        self.service = service
        self.train = train
        self.notifications = notifications
        self.calendar = calendar
        self.now = now
    }
}
