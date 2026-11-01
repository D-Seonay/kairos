import Foundation
import PulseContent
import PulseDomain

enum Fixtures {
    static func exercise(id: String, pattern: MovementPattern = .squat, alternatives: [String] = [], retired: Bool = false,
                         cues: Int = 3, mistakes: Int = 2, increment: Double = 2.5, rest: Int = 90,
                         primary: [Muscle] = [.quads], secondary: [Muscle] = [.glutes]) -> Exercise {
        Exercise(id: id, name: LocalizedText(fr: "Nom \(id)", en: "Name \(id)"), primaryMuscles: primary, secondaryMuscles: secondary,
                 equipment: .machine, pattern: pattern, region: .lower, isCompound: false, isUnilateral: false, loadKind: .external,
                 defaultIncrementKg: increment, defaultRestSeconds: rest,
                 cues: LocalizedList(fr: (0..<cues).map { "Consigne \($0)." }),
                 mistakes: LocalizedList(fr: (0..<mistakes).map { "Erreur \($0)." }),
                 alternatives: alternatives, retired: retired)
    }

    /// Quatre exercices `<prefix>-1…4` d'un même plan qui se citent mutuellement.
    static func fourExercises(pattern: MovementPattern, prefix: String = "p") -> [Exercise] {
        let ids = (1...4).map { "\(prefix)-\($0)" }
        return ids.map { id in exercise(id: id, pattern: pattern, alternatives: ids.filter { $0 != id }) }
    }

    static func library(exercises: [Exercise], templates: [ProgramTemplate] = []) -> ContentLibrary {
        ContentLibrary(catalog: ExerciseCatalog(schemaVersion: 1, contentVersion: "1.0.0", exercises: exercises), templates: templates)
    }

    static func template(id: String = "t", days: [TemplateDay], suggestedWeek: [String?], sessionsPerWeek: Int) -> ProgramTemplate {
        ProgramTemplate(id: id, name: LocalizedText(fr: "Modèle"), summary: LocalizedText(fr: "Résumé"),
                        recommendedFor: TemplateRecommendation(focus: .balanced, daysPerWeek: [3]),
                        sessionsPerWeek: sessionsPerWeek, days: days, suggestedWeek: suggestedWeek)
    }

    static func strengthDay(id: String, exercises: [TemplateExercise]) -> TemplateDay {
        TemplateDay(id: id, name: LocalizedText(fr: id), kind: .strength, exercises: exercises)
    }

    static func templateExercise(_ id: String, sets: Int = 3, repsMin: Int = 8, repsMax: Int = 12, rpe: Double = 8,
                                 rest: Int = 90, superset: Int? = nil) -> TemplateExercise {
        TemplateExercise(exercise: id, sets: sets, repsMin: repsMin, repsMax: repsMax, targetRPE: rpe,
                         restSeconds: rest, supersetGroup: superset)
    }
}
