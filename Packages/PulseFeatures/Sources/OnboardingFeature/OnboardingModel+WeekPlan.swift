import Foundation
import PulseDomain
import PulseServices

/// La semaine proposée : ce que l'étape des objectifs annonce, ce que les cartes de l'étape du programme dessinent et ce que
/// l'adoption enregistre viennent du même calcul, `plannedProgram(for:)`. Ils ne peuvent donc pas se contredire.
extension OnboardingModel {
    /// Les sorties que le curseur demande : les jours que la musculation, `round(jours × (1 − focus))`, ne prend pas.
    public var requestedRuns: Int {
        RunDayPlanner.requestedRuns(focus: profile.focus, daysPerWeek: profile.trainingDaysPerWeek)
    }

    /// Les séances de la semaine qu'adopter le modèle recommandé donnera : ses séances de musculation, et les sorties du
    /// curseur placées autour (celles du modèle comptent). Suit le curseur, les séances par semaine et les jours de repos.
    /// Sans modèle, le partage que demande le curseur.
    public var weekProposal: (strength: Int, runs: Int) {
        let recommendedID = recommendation()
        guard let template = environment.library.programTemplates.first(where: { $0.id == recommendedID }) else {
            return (profile.trainingDaysPerWeek - requestedRuns, requestedRuns)
        }
        let week = ProgramWeekPreview.days(of: plannedProgram(for: template))
        return (week.filter { $0.kind == .strength }.count, week.filter { $0.kind == .run }.count)
    }

    /// Le programme que l'adoption de `template` enregistre : adapté au matériel, aux douleurs et aux repos du brouillon, avec
    /// les sorties que le curseur demande.
    func plannedProgram(for template: ProgramTemplate) -> Program {
        adopter.adopt(template, equipment: profile.equipmentAccess, painAreas: profile.painAreas,
                      restWeekdays: profile.restWeekdays, runs: requestedRuns, now: environment.now())
    }

    /// L'aperçu L à D de la carte de `template` : la semaine de `plannedProgram(for:)`.
    func weekPreview(for template: ProgramTemplate) -> [WeekPreviewDay] {
        ProgramWeekPreview.days(of: plannedProgram(for: template))
    }
}
