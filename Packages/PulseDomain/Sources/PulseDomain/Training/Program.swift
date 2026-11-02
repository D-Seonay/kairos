import Foundation

/// Un exercice d'un jour de routine, avec ses paramètres (spec M2 §5.3).
public struct RoutineExercise: Sendable, Equatable, Codable, Identifiable {
    public var id: UUID
    public var order: Int
    public var exercise: ExerciseReference
    public var sets: Int
    public var repsMin: Int
    public var repsMax: Int
    public var targetRPE: Double
    public var restSeconds: Int
    public var supersetGroup: Int?
    /// Fourchette par série, quand elle diffère de `repsMin...repsMax` ; l'index est celui de la série, à partir de 0.
    public var setTargets: [SetTarget]?

    public init(id: UUID = UUID(), order: Int, exercise: ExerciseReference, sets: Int, repsMin: Int, repsMax: Int,
                targetRPE: Double, restSeconds: Int, supersetGroup: Int? = nil, setTargets: [SetTarget]? = nil) {
        self.id = id
        self.order = order
        self.exercise = exercise
        self.sets = sets
        self.repsMin = repsMin
        self.repsMax = repsMax
        self.targetRPE = targetRPE
        self.restSeconds = restSeconds
        self.supersetGroup = supersetGroup
        self.setTargets = setTargets
    }

    /// Fourchette de répétitions de la série `index` (à partir de 0) : sa cible propre si elle existe, sinon `repsMin...repsMax`.
    /// Une fourchette saisie à l'envers est rendue dans l'ordre : elle ne fait jamais planter.
    public func repRange(forSet index: Int) -> ClosedRange<Int> {
        if let setTargets, setTargets.indices.contains(index) {
            let target = setTargets[index]
            return min(target.repsMin, target.repsMax)...max(target.repsMin, target.repsMax)
        }
        return min(repsMin, repsMax)...max(repsMin, repsMax)
    }
}

/// Un jour d'un programme : musculation (exercices) ou course (type et objectif).
public struct RoutineDay: Sendable, Equatable, Codable, Identifiable {
    public var id: UUID
    public var order: Int
    public var name: String
    public var kind: RoutineDayKind
    public var runType: RunType?
    public var runTargetMinutes: Int?
    public var runTargetKm: Double?
    public var exercises: [RoutineExercise]

    public init(id: UUID = UUID(), order: Int, name: String, kind: RoutineDayKind, runType: RunType? = nil,
                runTargetMinutes: Int? = nil, runTargetKm: Double? = nil, exercises: [RoutineExercise] = []) {
        self.id = id
        self.order = order
        self.name = name
        self.kind = kind
        self.runType = runType
        self.runTargetMinutes = runTargetMinutes
        self.runTargetKm = runTargetKm
        self.exercises = exercises
    }
}

/// Le programme de l'utilisateur : copie d'un modèle ou création libre. `weekLayout` : 7 entrées, lundi à dimanche.
public struct Program: Sendable, Equatable, Codable, Identifiable {
    public var id: UUID
    public var name: String
    public var templateID: String?
    public var sessionsPerWeek: Int
    public var weekLayout: [UUID?]
    public var isArchived: Bool
    public var days: [RoutineDay]
    public var createdAt: Date
    public var updatedAt: Date

    public init(id: UUID = UUID(), name: String, templateID: String? = nil, sessionsPerWeek: Int, weekLayout: [UUID?],
                isArchived: Bool = false, days: [RoutineDay], createdAt: Date, updatedAt: Date) {
        self.id = id
        self.name = name
        self.templateID = templateID
        self.sessionsPerWeek = sessionsPerWeek
        self.weekLayout = weekLayout
        self.isArchived = isArchived
        self.days = days
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Copie un modèle du bundle en programme modifiable (spec M2 §4.3).
    public init(template: ProgramTemplate, now: Date) {
        let days = template.days.enumerated().map { index, day in
            RoutineDay(order: index, name: day.name.fr, kind: day.kind, runType: day.run?.type,
                       runTargetMinutes: day.run?.targetMinutes, runTargetKm: day.run?.targetKm,
                       exercises: day.exercises.enumerated().map { position, exercise in
                           RoutineExercise(order: position, exercise: .content(id: exercise.exercise), sets: exercise.sets,
                                           repsMin: exercise.repsMin, repsMax: exercise.repsMax, targetRPE: exercise.targetRPE,
                                           restSeconds: exercise.restSeconds, supersetGroup: exercise.supersetGroup)
                       })
        }
        let idsByTemplateDay = Dictionary(zip(template.days.map(\.id), days.map(\.id)), uniquingKeysWith: { first, _ in first })
        self.init(name: template.name.fr, templateID: template.id, sessionsPerWeek: template.sessionsPerWeek,
                  weekLayout: template.suggestedWeek.map { $0.flatMap { idsByTemplateDay[$0] } },
                  days: days, createdAt: now, updatedAt: now)
    }
}
