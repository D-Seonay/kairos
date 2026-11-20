import Foundation
import PulseDomain
import PulseServices

/// Tout ce dont les écrans des compléments ont besoin du dehors : le service des compléments, l'autorisation des notifications
/// et l'horloge.
public struct SupplementsEnvironment: Sendable {
    public var service: SupplementService
    public var notifications: any NotificationAuthorizing
    public var calendar: Calendar
    public var now: @Sendable () -> Date

    public init(service: SupplementService, notifications: any NotificationAuthorizing, calendar: Calendar,
                now: @escaping @Sendable () -> Date) {
        self.service = service
        self.notifications = notifications
        self.calendar = calendar
        self.now = now
    }
}
