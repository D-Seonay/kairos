import PulseDomain

/// Choisit le modèle de programme proposé à l'onboarding : le curseur force / endurance donne le focus, le nombre de séances départage.
public enum TemplateRecommender {
    /// Moins de 0,35 : force ; plus de 0,65 : endurance ; entre les deux : équilibré.
    public static func focus(for value: Double) -> TrainingFocus {
        if value < 0.35 { .strength } else if value > 0.65 { .endurance } else { .balanced }
    }

    /// Parmi les modèles du focus, le premier qui couvre ce nombre de jours, sinon celui dont le jour est le plus proche.
    /// Sans modèle pour le focus, le premier modèle ; nil sans aucun modèle.
    public static func recommendedID(focus value: Double, daysPerWeek: Int, templates: [ProgramTemplate]) -> String? {
        let candidates = templates.filter { $0.recommendedFor.focus == focus(for: value) }
        guard !candidates.isEmpty else { return templates.first?.id }
        if let exact = candidates.first(where: { $0.recommendedFor.daysPerWeek.contains(daysPerWeek) }) {
            return exact.id
        }
        var best = candidates[0]
        var bestDistance = distance(of: best, to: daysPerWeek)
        for template in candidates.dropFirst() {
            let candidateDistance = distance(of: template, to: daysPerWeek)
            if candidateDistance < bestDistance {
                best = template
                bestDistance = candidateDistance
            }
        }
        return best.id
    }

    private static func distance(of template: ProgramTemplate, to days: Int) -> Int {
        template.recommendedFor.daysPerWeek.map { abs($0 - days) }.min() ?? Int.max
    }
}
