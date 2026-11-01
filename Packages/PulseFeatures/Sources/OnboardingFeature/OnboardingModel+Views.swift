import Foundation
import PulseDomain

extension OnboardingModel {
    /// Les modèles de la bibliothèque, le recommandé en tête, les autres dans l'ordre de la bibliothèque.
    public var templates: [ProgramTemplate] {
        let all = environment.library.programTemplates
        guard let recommended = all.first(where: { $0.id == recommendedTemplateID }) else { return all }
        return [recommended] + all.filter { $0.id != recommended.id }
    }

    /// La date proposée quand la date de naissance est renseignée à la main : trente ans avant aujourd'hui.
    public var suggestedBirthDate: Date {
        let calendar = environment.calendar
        let today = calendar.startOfDay(for: environment.now())
        return calendar.date(byAdding: .year, value: -30, to: today) ?? today
    }

    /// La dernière date de naissance possible : aujourd'hui.
    public var latestBirthDate: Date {
        environment.now()
    }
}
