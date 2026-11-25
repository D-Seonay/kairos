import Foundation
import PulseServices

// MARK: - Rappel de photos

extension BodyPhotosModel {
    /// Le rappel se règle quand la section est lisible : les dates des photos donnent la prochaine échéance.
    public var offersReminder: Bool { reminders != nil }

    /// La date de la photo la plus récente, d'où part le rappel suivant.
    var lastPhotoDate: Date? {
        photos.map(\.takenAt).max()
    }

    /// Change le rythme du rappel et le replanifie depuis la dernière photo. Rien ne change tant que la section est verrouillée.
    public func setReminderInterval(_ interval: BodyPhotoReminderInterval) async {
        guard let reminders, canReadFiles, interval != reminderInterval else { return }
        reminderInterval = interval
        await reminders.setInterval(interval, lastPhoto: lastPhotoDate, now: today)
        await refreshNotificationStatus()
    }

    /// Relit l'état des notifications dans les réglages d'iOS (à l'apparition du réglage, au retour au premier plan).
    public func refreshNotificationStatus() async {
        notificationsDenied = await reminders?.notificationsDenied() ?? false
    }

    /// Une photo ajoutée ou supprimée déplace la dernière date : le rappel repart d'elle.
    func rescheduleReminder() async {
        guard let reminders, reminderInterval != .off, canReadFiles else { return }
        await reminders.reschedule(lastPhoto: lastPhotoDate, now: today)
    }
}
