import PulseDomain

/// Choisit le modèle de programme proposé à l'onboarding : le curseur force / endurance donne le focus, les séances de
/// musculation que le curseur laisse dans la semaine départagent.
public enum TemplateRecommender {
    /// Moins de 0,35 : force ; plus de 0,65 : endurance ; entre les deux : équilibré.
    public static func focus(for value: Double) -> TrainingFocus {
        if value < 0.35 { .strength } else if value > 0.65 { .endurance } else { .balanced }
    }

    /// Parmi les modèles du focus, celui dont le nombre de jours de musculation est le plus proche de ce que la semaine en
    /// demande (`WeekSplit.strength` : les séances par semaine moins les sorties du curseur) ; à égalité, le premier dans l'ordre
    /// de la bibliothèque. Le total de séances ne compte pas : quelqu'un qui veut 4 séances dont 2 sorties reçoit un modèle
    /// pensé pour 2 ou 3 séances de musculation, pas pour 4.
    /// Sans modèle pour le focus, le premier modèle ; nil sans aucun modèle.
    public static func recommendedID(focus value: Double, daysPerWeek: Int, templates: [ProgramTemplate]) -> String? {
        let candidates = templates.filter { $0.recommendedFor.focus == focus(for: value) }
        guard var best = candidates.first else { return templates.first?.id }
        let strength = WeekSplit(focus: value, daysPerWeek: daysPerWeek).strength
        var bestDistance = abs(best.strengthDaysPerWeek - strength)
        for template in candidates.dropFirst() {
            let distance = abs(template.strengthDaysPerWeek - strength)
            if distance < bestDistance {
                best = template
                bestDistance = distance
            }
        }
        return best.id
    }
}

extension ProgramTemplate {
    /// Le nombre de jours de musculation de la semaine suggérée du modèle.
    public var strengthDaysPerWeek: Int {
        let strengthIDs = Set(days.filter { $0.kind == .strength }.map(\.id))
        return suggestedWeek.compactMap { $0 }.filter(strengthIDs.contains).count
    }

    /// Vrai si la semaine du modèle peut être adoptée avec moins de séances de musculation qu'il n'en prévoit : seules ses
    /// premières routines sont alors placées, les autres restent dans le programme, hors semaine.
    ///
    /// C'est le cas des modèles équilibrés (Full Body, Haut / Bas) : leurs premières routines couvrent déjà tout le corps, en
    /// retirer une réduit la fréquence sans laisser un muscle de côté. Un split (Push / Pull / Legs) ne se raccourcit pas :
    /// chaque jour y porte un groupe musculaire, retirer un jour retire ce groupe de la semaine. Le modèle d'endurance non
    /// plus : ses deux séances de force sont déjà le minimum autour de ses courses.
    public var canBeShortened: Bool {
        recommendedFor.focus == .balanced
    }
}
