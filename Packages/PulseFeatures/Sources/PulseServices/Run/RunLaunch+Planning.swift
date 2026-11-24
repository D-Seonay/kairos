import Foundation
import PulseContent
import PulseDomain
import PulseRecoveryEngine

extension RunLaunch {
    /// La course planifiée du jour, après l'ajustement du moteur, titrée comme la carte de l'accueil.
    /// `.swapIntervalsForEasy` → `runType: .easy`, `adjustmentNote` « au lieu du fractionné » ;
    /// `.suggestRest` → objectif gardé, `adjustmentNote` « repos conseillé aujourd'hui ».
    public static func planned(_ day: RoutineDay, programID: UUID?, adjusted: AdjustedSession?) -> RunLaunch {
        let kinds = adjusted?.adjustments.map(\.kind) ?? []
        var runType = day.runType
        var note: String?
        // Même priorité que la carte de l'accueil : le repos conseillé passe avant l'échange du fractionné.
        if kinds.contains(.suggestRest) {
            note = String(localized: "repos conseillé aujourd'hui", bundle: .module)
        } else if kinds.contains(.swapIntervalsForEasy) {
            runType = .easy
            note = String(localized: "au lieu du fractionné", bundle: .module)
        }
        return RunLaunch(
            title: runType?.localizedName ?? day.name, programID: programID, routineDayID: day.id, runType: runType,
            targetMinutes: day.runTargetMinutes, targetKm: day.runTargetKm, adjustmentNote: note)
    }

    /// Une course lancée depuis l'onglet Séance, sans objectif.
    public static func free() -> RunLaunch {
        RunLaunch(title: String(localized: "Course libre", bundle: .module))
    }
}
