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

    /// Les séances de la semaine qu'adopter le modèle recommandé donnera, jamais plus que les séances par semaine choisies
    /// (sauf si le modèle seul en compte plus) : les séances de musculation que le modèle garde, et les sorties du curseur
    /// qui trouvent un jour libre (celles du modèle comptent). Une sortie sans place n'est pas annoncée. Suit le curseur, les
    /// séances par semaine et les jours de repos. Sans modèle, le partage que demande le curseur.
    public var weekProposal: (strength: Int, runs: Int) {
        let recommendedID = recommendation()
        guard let template = environment.library.programTemplates.first(where: { $0.id == recommendedID }) else {
            return (profile.trainingDaysPerWeek - requestedRuns, requestedRuns)
        }
        let week = ProgramWeekPreview.days(of: plannedProgram(for: template))
        return (week.filter { $0.kind == .strength }.count, week.filter { $0.kind == .run }.count)
    }

    /// Le programme que l'adoption de `template` enregistre : adapté au matériel, aux douleurs et aux repos du brouillon, et
    /// au partage de la semaine que demande le curseur (`WeekSplit`, appliqué par `ProgramAdopter`).
    func plannedProgram(for template: ProgramTemplate) -> Program {
        adopter.adopt(template, equipment: profile.equipmentAccess, painAreas: profile.painAreas,
                      restWeekdays: profile.restWeekdays,
                      split: WeekSplit(focus: profile.focus, daysPerWeek: profile.trainingDaysPerWeek), now: environment.now())
    }

    /// Ce que la carte de `template` montre : la semaine de `plannedProgram(for:)` et les routines qu'elle laisse de côté.
    func weekPlan(for template: ProgramTemplate) -> TemplateWeekPlan {
        let program = plannedProgram(for: template)
        let placed = Set(program.weekLayout.compactMap { $0 })
        return TemplateWeekPlan(week: ProgramWeekPreview.days(of: program),
                                unplacedRoutines: program.days.filter { $0.kind == .strength && !placed.contains($0.id) }.count)
    }

    /// L'aperçu L à D de la carte de `template`.
    func weekPreview(for template: ProgramTemplate) -> [WeekPreviewDay] {
        weekPlan(for: template).week
    }
}

/// La semaine que l'adoption d'un modèle donnera, pour sa carte.
struct TemplateWeekPlan: Equatable {
    let week: [WeekPreviewDay]
    /// Les routines de musculation du programme qui ne tombent sur aucun jour : celles qu'un modèle raccourci garde de côté,
    /// ou celles que les repos obligatoires n'ont pas laissé placer.
    let unplacedRoutines: Int
}
