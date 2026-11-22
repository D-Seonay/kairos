import PulseDesignSystem
import PulseServices

extension RecapView {
    /// Une tuile du bilan, avec le nom et la valeur que VoiceOver en dit.
    enum Stat {
        case duration(minutes: Int)
        case tonnage(kg: Double)
        case sets(Int)
        case records(Int)
    }

    /// « Nouveau record ! Développé couché : 72,5 kilos, nouveau record de charge », « 3 nouveaux records ! … » (le premier
    /// seulement : les autres sont dans la carte) ; `nil` sans record.
    nonisolated static func recordsAnnouncement(_ records: [BeatenRecord]) -> String? {
        guard let first = records.first else { return nil }
        let lead = records.count == 1
            ? String(localized: "Nouveau record !", bundle: .module)
            : String(localized: "\(records.count) nouveaux records !", bundle: .module)
        return String(localized: "\(lead) \(first.spokenText)", bundle: .module)
    }

    /// Le nom et la valeur dits d'une tuile : « Durée, 55 minutes », « Tonnage, 12 450 kilos », « Séries, 14 séries »,
    /// « Records, 2 ».
    nonisolated static func statSpoken(_ stat: Stat) -> (name: String, value: String) {
        switch stat {
        case .duration(let minutes):
            (String(localized: "Durée", bundle: .module), PulseSpoken.duration(seconds: minutes * 60))
        case .tonnage(let kg):
            (String(localized: "Tonnage", bundle: .module), LiveHeader.tonnageSpokenText(kg: kg))
        case .sets(let count):
            (String(localized: "Séries", bundle: .module),
             PulseSpoken.count(count, singular: String(localized: "série", bundle: .module),
                               plural: String(localized: "séries", bundle: .module)))
        case .records(let count):
            (recordsTitle(count), "\(count)")
        }
    }
}
