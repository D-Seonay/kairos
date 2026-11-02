import Foundation
import PulseDomain
import PulseRecoveryEngine

/// L'état d'une séance en cours. Il est écrit en JSON dans `ActiveSessionSnapshot.payload` après chaque changement
/// (spec M4 §16) ; `formatVersion` permet de refuser un format que cette version ne sait pas lire.
public struct LiveSession: Sendable, Equatable, Codable, Identifiable {
    public static let currentFormat = 1

    public var formatVersion: Int
    public var id: UUID
    public var title: String
    public var startedAt: Date
    public var lastActionAt: Date
    public var programID: UUID?
    public var routineDayID: UUID?
    public var appliedAdjustments: [SessionAdjustment]
    public var refusedAdjustments: [SessionAdjustment]
    public var exercises: [LiveExercise]
    public var rest: LiveRest?

    public init(formatVersion: Int = LiveSession.currentFormat, id: UUID = UUID(), title: String, startedAt: Date,
                lastActionAt: Date, programID: UUID? = nil, routineDayID: UUID? = nil,
                appliedAdjustments: [SessionAdjustment] = [], refusedAdjustments: [SessionAdjustment] = [],
                exercises: [LiveExercise] = [], rest: LiveRest? = nil) {
        self.formatVersion = formatVersion
        self.id = id
        self.title = title
        self.startedAt = startedAt
        self.lastActionAt = lastActionAt
        self.programID = programID
        self.routineDayID = routineDayID
        self.appliedAdjustments = appliedAdjustments
        self.refusedAdjustments = refusedAdjustments
        self.exercises = exercises
        self.rest = rest
    }

    /// Les séries de travail prévues, échauffement exclu.
    public var plannedWorkingSets: Int {
        exercises.reduce(0) { $0 + $1.sets.filter { $0.setType != .warmup }.count }
    }

    /// Les séries de travail validées.
    public var doneWorkingSets: Int {
        exercises.reduce(0) { $0 + $1.sets.filter { $0.setType != .warmup && $0.completedAt != nil }.count }
    }

    /// Le tonnage des séries validées (spec M4 §8.2).
    public var tonnageKg: Double {
        exercises.reduce(0) { total, exercise in
            let done = exercise.sets.filter { $0.completedAt != nil }.map { set in
                WorkoutSet(order: 0, exercise: exercise.exercise, exerciseName: exercise.name, setType: set.setType,
                           actualWeightKg: set.weightKg, actualReps: set.reps)
            }
            return total + SessionTonnage.kilograms(of: done, loadKind: { _ in exercise.loadKind })
        }
    }

    /// La prochaine série non validée, dans l'ordre de la séance. Les exercices d'un même super set alternent :
    /// A1, B1, A2, B2…
    public var nextSet: (exerciseIndex: Int, setIndex: Int)? {
        var start = 0
        while start < exercises.count {
            let end = blockEnd(from: start)
            let rounds = exercises[start..<end].map(\.sets.count).max() ?? 0
            for round in 0..<rounds {
                for index in start..<end where round < exercises[index].sets.count && exercises[index].sets[round].completedAt == nil {
                    return (index, round)
                }
            }
            start = end
        }
        return nil
    }

    /// Fin du bloc qui commence à `start` : l'exercice seul, ou les exercices voisins du même super set.
    private func blockEnd(from start: Int) -> Int {
        guard let group = exercises[start].supersetGroup else { return start + 1 }
        var end = start + 1
        while end < exercises.count, exercises[end].supersetGroup == group { end += 1 }
        return end
    }

    public func encoded() throws -> Data {
        try JSONEncoder().encode(self)
    }

    /// Rend `nil` pour un format inconnu ou un JSON illisible : l'appelant propose alors d'abandonner la séance.
    public static func decode(_ data: Data) -> LiveSession? {
        struct Header: Decodable { var formatVersion: Int }
        guard let header = try? JSONDecoder().decode(Header.self, from: data), header.formatVersion == currentFormat else {
            return nil
        }
        return try? JSONDecoder().decode(LiveSession.self, from: data)
    }
}

public struct LiveExercise: Sendable, Equatable, Codable, Identifiable {
    public var id: UUID
    public var exercise: ExerciseReference
    public var name: String
    public var loadKind: LoadKind
    public var tracksDuration: Bool
    public var isBarbell: Bool
    public var incrementKg: Double
    public var supersetGroup: Int?
    /// Le repos de la routine, avec le supplément du jour.
    public var restSeconds: Int
    public var rpeCap: Double?
    /// Ce que le jour a changé, ou la raison de la hausse (spec M4 §14.3).
    public var dayNote: String?
    /// « Dernière fois 70 × 5 · 5 ».
    public var lastTimeText: String?
    public var note: String?
    public var sets: [LiveSet]

    public init(id: UUID = UUID(), exercise: ExerciseReference, name: String, loadKind: LoadKind, tracksDuration: Bool,
                isBarbell: Bool, incrementKg: Double, supersetGroup: Int? = nil, restSeconds: Int, rpeCap: Double? = nil,
                dayNote: String? = nil, lastTimeText: String? = nil, note: String? = nil, sets: [LiveSet]) {
        self.id = id
        self.exercise = exercise
        self.name = name
        self.loadKind = loadKind
        self.tracksDuration = tracksDuration
        self.isBarbell = isBarbell
        self.incrementKg = incrementKg
        self.supersetGroup = supersetGroup
        self.restSeconds = restSeconds
        self.rpeCap = rpeCap
        self.dayNote = dayNote
        self.lastTimeText = lastTimeText
        self.note = note
        self.sets = sets
    }
}

/// Une série en séance. Tant que `isEdited` est faux, `weightKg`, `reps` et `durationSeconds` valent la proposition.
public struct LiveSet: Sendable, Equatable, Codable, Identifiable {
    public var id: UUID
    public var setType: SetType
    /// La même série la dernière fois : « 70 × 5 ».
    public var previous: String?
    public var proposed: ProposedSet
    public var weightKg: Double?
    public var reps: Int?
    public var durationSeconds: Int?
    public var rpe: Double?
    /// Vrai quand une valeur a été changée à la main.
    public var isEdited: Bool
    public var completedAt: Date?

    public init(id: UUID = UUID(), setType: SetType = .working, previous: String? = nil, proposed: ProposedSet,
                weightKg: Double? = nil, reps: Int? = nil, durationSeconds: Int? = nil, rpe: Double? = nil,
                isEdited: Bool = false, completedAt: Date? = nil) {
        self.id = id
        self.setType = setType
        self.previous = previous
        self.proposed = proposed
        self.weightKg = weightKg
        self.reps = reps
        self.durationSeconds = durationSeconds
        self.rpe = rpe
        self.isEdited = isEdited
        self.completedAt = completedAt
    }

    /// Une série qui prend les valeurs de sa proposition.
    public init(proposed: ProposedSet, previous: String?) {
        self.init(previous: previous, proposed: proposed, weightKg: proposed.weightKg, reps: proposed.reps,
                  durationSeconds: proposed.durationSeconds)
    }
}

/// Le chrono de repos en cours.
public struct LiveRest: Sendable, Equatable, Codable {
    public var startedAt: Date
    public var endsAt: Date
    public var exerciseID: UUID

    public init(startedAt: Date, endsAt: Date, exerciseID: UUID) {
        self.startedAt = startedAt
        self.endsAt = endsAt
        self.exerciseID = exerciseID
    }
}
