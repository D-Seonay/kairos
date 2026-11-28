import PulseDomain
import UserNotifications

extension UNUserNotificationCenter {
    /// `add` qui journalise : une demande refusée (autorisation retirée, plafond de notifications) ne fait rien d'autre,
    /// comme avant.
    func addLogged(_ request: UNNotificationRequest) async {
        do {
            try await add(request)
        } catch {
            logger.failure("Notification non programmée", error)
        }
    }
}
