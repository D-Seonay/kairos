import Foundation
import PulseServices

// MARK: - Rappel de check-in

extension SettingsModel {
    /// Allume ou coupe le rappel de check-in : l'écran suit tout de suite. L'allumer demande l'autorisation des notifications si
    /// elle n'a pas encore été donnée ; refusée, le lien vers les réglages d'iOS s'affiche.
    func setCheckInReminderEnabled(_ enabled: Bool) async {
        guard let service = environment.checkInReminders else { return }
        checkInReminder?.enabled = enabled
        await service.setEnabled(enabled)
        checkInReminder = service.settings
        if enabled { await refreshNotificationStatus() }
    }

    /// L'heure du rappel ; `nil` : au réveil habituel.
    func setCheckInReminderMinutes(_ minutes: Int?) async {
        guard let service = environment.checkInReminders else { return }
        checkInReminder?.chosenMinutes = minutes
        await service.setChosenMinutes(minutes)
        checkInReminder = service.settings
    }
}
