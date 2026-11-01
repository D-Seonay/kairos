import Foundation

/// Position du curseur force / endurance qui pré-sélectionne un modèle (spec V1 §5.1).
public enum TrainingFocus: String, Sendable, Codable, CaseIterable {
    case strength
    case balanced
    case endurance
}

/// Nature d'un jour de routine.
public enum RoutineDayKind: String, Sendable, Codable, CaseIterable {
    case strength
    case run
}

/// Type d'une course planifiée (spec V1 §5.4).
public enum RunType: String, Sendable, Codable, CaseIterable {
    case easy
    case intervals
    case long
}

/// Objectif d'un jour de course : durée ou distance, jamais les deux.
public struct RunTarget: Sendable, Equatable, Codable {
    public var type: RunType
    public var targetMinutes: Int?
    public var targetKm: Double?

    public init(type: RunType, targetMinutes: Int? = nil, targetKm: Double? = nil) {
        self.type = type
        self.targetMinutes = targetMinutes
        self.targetKm = targetKm
    }
}

/// Un exercice d'un jour de modèle, avec ses paramètres (spec M2 §4.3).
public struct TemplateExercise: Sendable, Equatable, Codable {
    public var exercise: String
    public var sets: Int
    public var repsMin: Int
    public var repsMax: Int
    public var targetRPE: Double
    public var restSeconds: Int
    public var supersetGroup: Int?

    public init(exercise: String, sets: Int, repsMin: Int, repsMax: Int, targetRPE: Double,
                restSeconds: Int, supersetGroup: Int? = nil) {
        self.exercise = exercise
        self.sets = sets
        self.repsMin = repsMin
        self.repsMax = repsMax
        self.targetRPE = targetRPE
        self.restSeconds = restSeconds
        self.supersetGroup = supersetGroup
    }
}

/// Un jour d'un modèle de programme : musculation (exercices) ou course (objectif).
public struct TemplateDay: Sendable, Equatable, Codable, Identifiable {
    public var id: String
    public var name: LocalizedText
    public var kind: RoutineDayKind
    public var exercises: [TemplateExercise]
    public var run: RunTarget?

    public init(id: String, name: LocalizedText, kind: RoutineDayKind, exercises: [TemplateExercise] = [], run: RunTarget? = nil) {
        self.id = id
        self.name = name
        self.kind = kind
        self.exercises = exercises
        self.run = run
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(LocalizedText.self, forKey: .name)
        kind = try container.decode(RoutineDayKind.self, forKey: .kind)
        exercises = try container.decodeIfPresent([TemplateExercise].self, forKey: .exercises) ?? []
        run = try container.decodeIfPresent(RunTarget.self, forKey: .run)
    }
}

/// Pour qui le modèle est proposé à l'onboarding.
public struct TemplateRecommendation: Sendable, Equatable, Codable {
    public var focus: TrainingFocus
    public var daysPerWeek: [Int]

    public init(focus: TrainingFocus, daysPerWeek: [Int]) {
        self.focus = focus
        self.daysPerWeek = daysPerWeek
    }
}

/// Un modèle de programme du bundle (spec M2 §4.3). `suggestedWeek` : 7 entrées, lundi à dimanche.
public struct ProgramTemplate: Sendable, Equatable, Codable, Identifiable {
    public var schemaVersion: Int
    public var id: String
    public var name: LocalizedText
    public var summary: LocalizedText
    public var recommendedFor: TemplateRecommendation
    public var sessionsPerWeek: Int
    public var days: [TemplateDay]
    public var suggestedWeek: [String?]

    public init(schemaVersion: Int = 1, id: String, name: LocalizedText, summary: LocalizedText,
                recommendedFor: TemplateRecommendation, sessionsPerWeek: Int, days: [TemplateDay], suggestedWeek: [String?]) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.name = name
        self.summary = summary
        self.recommendedFor = recommendedFor
        self.sessionsPerWeek = sessionsPerWeek
        self.days = days
        self.suggestedWeek = suggestedWeek
    }
}
