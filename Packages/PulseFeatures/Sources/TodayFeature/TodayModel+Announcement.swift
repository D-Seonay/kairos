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

    /// « Synchro, 8 heures 30 », « Synchro, hier, 8 heures 30 », « Synchro, pas encore » : le mot affiché (pour la Commande
    /// vocale) suivi du jour quand ce n'est pas aujourd'hui (`now` donné), puis de l'heure de la dernière lecture dite en toutes
    /// lettres.
    nonisolated static func syncAccessibilityText(lastSync: Date?, calendar: Calendar, now: Date? = nil) -> String {
        guard let lastSync else { return String(localized: "Synchro, pas encore", bundle: .module) }
        let parts = calendar.dateComponents([.hour, .minute], from: lastSync)
        let time = PulseSpoken.clock(hour: parts.hour ?? 0, minute: parts.minute ?? 0)
        if let now, let day = syncDay(lastSync, now: now, calendar: calendar, spoken: true) {
            return String(localized: "Synchro, \(day), \(time)", bundle: .module)
        }
        return String(localized: "Synchro, \(time)", bundle: .module)
    }

    /// Le jour de la dernière synchro quand ce n'est pas aujourd'hui : « hier », puis « 30 oct. » (« 30 octobre » pour VoiceOver) ;
    /// `nil` le jour même.
    nonisolated static func syncDay(_ date: Date, now: Date, calendar: Calendar, spoken: Bool) -> String? {
        if calendar.isDate(date, inSameDayAs: now) { return nil }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(date, inSameDayAs: yesterday) {
            return String(localized: "hier", bundle: .module)
        }
        // Un style de format, pas un `DateFormatter` coûteux recréé à chaque rendu de l'en-tête.
        let style = Date.FormatStyle(locale: Locale(identifier: "fr_FR"), calendar: calendar, timeZone: calendar.timeZone)
        return date.formatted(style.day().month(spoken ? .wide : .abbreviated))
    }

    /// L'étiquette de la pastille de synchronisation.
    var syncAccessibilityText: String {
        Self.syncAccessibilityText(lastSync: lastSync, calendar: environment.calendar, now: environment.now())
    }

    /// Le marqueur du score du jour tel que VoiceOver le dit : « estimé », « en calibration, 9 nuits ».
    var spokenMarker: String? {
        scoredToday.flatMap(FactorFormatter.spokenMarker(for:))
    }
}
