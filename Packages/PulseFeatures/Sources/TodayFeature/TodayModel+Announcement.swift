import Foundation
import PulseDesignSystem
import PulseDomain
import PulseServices

extension TodayModel {
    /// L'annonce VoiceOver quand le score du jour arrive ou change ; `nil` quand il n'y a rien à dire : pas de score du jour, ou
    /// la même note affichée dans la même catégorie. « Ton score est prêt : … » la première fois, « Score mis à jour : … » ensuite.
    nonisolated static func scoreAnnouncement(old: TodayScore?, new: TodayScore?) -> String? {
        guard case .scored(let recovery)? = new else { return nil }
        let marker = FactorFormatter.spokenMarker(for: recovery)
        let text = RecoveryCardText.gaugeLabel(recovery: recovery, marker: marker)
        guard case .scored(let previous)? = old else {
            return String(localized: "Ton score est prêt : \(text)", bundle: .module)
        }
        let before = RecoveryCardText.gaugeLabel(recovery: previous, marker: nil)
        guard before != RecoveryCardText.gaugeLabel(recovery: recovery, marker: nil) else { return nil }
        return String(localized: "Score mis à jour : \(text)", bundle: .module)
    }

    /// « Synchronisé à 8 heures 30 », « Pas encore synchronisé » : l'heure de la dernière lecture dite en toutes lettres.
    nonisolated static func syncAccessibilityText(lastSync: Date?, calendar: Calendar) -> String {
        guard let lastSync else { return String(localized: "Pas encore synchronisé", bundle: .module) }
        let parts = calendar.dateComponents([.hour, .minute], from: lastSync)
        let time = PulseSpoken.clock(hour: parts.hour ?? 0, minute: parts.minute ?? 0)
        return String(localized: "Synchronisé à \(time)", bundle: .module)
    }

    /// L'étiquette de la pastille de synchronisation.
    var syncAccessibilityText: String {
        Self.syncAccessibilityText(lastSync: lastSync, calendar: environment.calendar)
    }

    /// Le marqueur du score du jour tel que VoiceOver le dit : « estimé », « en calibration, 9 nuits ».
    var spokenMarker: String? {
        scoredToday.flatMap(FactorFormatter.spokenMarker(for:))
    }
}
