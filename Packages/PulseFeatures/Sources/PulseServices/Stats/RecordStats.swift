import Foundation
import PulseDomain

/// La ligne de force d'un exercice : son record actuel et la série qui l'a donné.
public struct StrengthRecordLine: Sendable, Equatable, Identifiable {
    public var exercise: ExerciseReference
    public var name: String
    /// `.estimatedOneRepMax`, ou `.repsAtWeight` pour un exercice sans 1RM (poids du corps).
    public var kind: RecordKind
    public var value: Double
    /// La série d'origine, retrouvée par `setID` ; `nil` si elle n'est plus dans l'historique.
    public var weightKg: Double?
    public var reps: Int?
    public var date: Date
    /// L'écart avec le meilleur record d'avant la période ; `nil` sans record antérieur ou si le record actuel l'est lui-même.
    public var gain: Double?
    public var isNew: Bool

    public var id: ExerciseReference { exercise }

    public init(exercise: ExerciseReference, name: String, kind: RecordKind, value: Double, weightKg: Double?, reps: Int?,
                date: Date, gain: Double?, isNew: Bool) {
        self.exercise = exercise
        self.name = name
        self.kind = kind
        self.value = value
        self.weightKg = weightKg
        self.reps = reps
        self.date = date
        self.gain = gain
        self.isNew = isNew
    }
}

public enum RunDistance: Double, CaseIterable, Sendable {
    case fiveK = 5_000
    case tenK = 10_000
    case half = 21_097.5
}

/// Le meilleur temps sur une distance, ramené à l'allure moyenne de la sortie qui la couvre.
public struct RunBest: Sendable, Equatable, Identifiable {
    public var distance: RunDistance
    public var seconds: Double?
    /// Le début de la sortie qui donne le temps.
    public var date: Date?
    public var isNew: Bool

    public var id: RunDistance { distance }

    public init(distance: RunDistance, seconds: Double?, date: Date?, isNew: Bool) {
        self.distance = distance
        self.seconds = seconds
        self.date = date
        self.isNew = isNew
    }
}

/// La vue Records : records de force (1RM ou répétitions) et meilleurs temps de course (spec M7 §10).
/// Un record ignore la période ; elle ne sert qu'à marquer ce qui a été battu dedans.
public struct RecordStats: Sendable, Equatable {
    public static let mainLifts: [String] = ["back-squat-barbell", "bench-press-barbell", "deadlift-barbell", "overhead-press-barbell"]
    /// Un exercice hors des quatre levés de base apparaît à partir de ce nombre de séances terminées.
    public static let minimumSessions = 5

    public var strength: [StrengthRecordLine]
    /// Toujours trois lignes, une par distance, dans l'ordre de `RunDistance.allCases`.
    public var runs: [RunBest]

    public init(strength: [StrengthRecordLine], runs: [RunBest]) {
        self.strength = strength
        self.runs = runs
    }

    // swiftlint:disable:next function_parameter_count
    public static func make(records: [PersonalRecord], sessions: [WorkoutSession], directory: ExerciseDirectory,
                            period: StatsPeriod, now: Date, calendar: Calendar) -> RecordStats {
        let interval = period.interval(now: now, calendar: calendar)
        return RecordStats(
            strength: strengthLines(records: records, sessions: sessions, directory: directory, interval: interval),
            runs: runBests(sessions: sessions, interval: interval))
    }

    // MARK: - Force

    private static func strengthLines(records: [PersonalRecord], sessions: [WorkoutSession], directory: ExerciseDirectory,
                                      interval: DateInterval) -> [StrengthRecordLine] {
        var exercises: [ExerciseReference] = []
        var byExercise: [ExerciseReference: [PersonalRecord]] = [:]
        for record in records {
            if byExercise[record.exercise] == nil { exercises.append(record.exercise) }
            byExercise[record.exercise, default: []].append(record)
        }
        let sets = Dictionary(
            sessions.flatMap(\.sets).map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        let lines = exercises.compactMap { exercise -> StrengthRecordLine? in
            guard let all = byExercise[exercise] else { return nil }
            let oneRepMaxes = all.filter { $0.kind == .estimatedOneRepMax }
            let candidates = oneRepMaxes.isEmpty ? all.filter { $0.kind == .repsAtWeight } : oneRepMaxes
            guard let current = best(of: candidates) else { return nil }
            let set = current.setID.flatMap { sets[$0] }
            return StrengthRecordLine(
                exercise: exercise, name: directory.name(of: exercise, fallback: current.exerciseName), kind: current.kind,
                value: current.value, weightKg: set?.actualWeightKg, reps: set?.actualReps, date: current.date,
                gain: gain(current: current, among: candidates, before: interval.start), isNew: contains(interval, current.date))
        }

        let main = mainLifts.compactMap { id in lines.first { $0.exercise == .content(id: id) } }
        let counts = sessionCounts(sessions)
        let others = lines
            .filter { line in
                !main.contains { $0.exercise == line.exercise } && (counts[line.exercise] ?? 0) >= minimumSessions
            }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        return main + others
    }

    /// La plus grande valeur ; à égalité, la plus ancienne (elle a été posée la première).
    private static func best(of records: [PersonalRecord]) -> PersonalRecord? {
        records.min { $0.value != $1.value ? $0.value > $1.value : $0.date < $1.date }
    }

    private static func gain(current: PersonalRecord, among records: [PersonalRecord], before start: Date) -> Double? {
        guard current.date >= start,
              let previous = best(of: records.filter { $0.date < start }) else { return nil }
        return current.value - previous.value
    }

    /// Le nombre de séances terminées où l'exercice a au moins une série hors échauffement.
    private static func sessionCounts(_ sessions: [WorkoutSession]) -> [ExerciseReference: Int] {
        var counts: [ExerciseReference: Int] = [:]
        for session in sessions where session.status == .completed {
            for exercise in Set(session.sets.filter { $0.setType != .warmup }.map(\.exercise)) {
                counts[exercise, default: 0] += 1
            }
        }
        return counts
    }

    // MARK: - Course

    private static func runBests(sessions: [WorkoutSession], interval: DateInterval) -> [RunBest] {
        let runs = sessions.filter { $0.kind == .run && $0.status == .completed }
        return RunDistance.allCases.map { distance in
            let timed = runs.compactMap { run -> (seconds: Double, date: Date)? in
                guard let meters = run.distanceMeters, meters >= distance.rawValue,
                      let minutes = run.durationMinutes, minutes > 0 else { return nil }
                return (minutes * 60 * distance.rawValue / meters, run.startedAt)
            }
            guard let winner = timed.min(by: { $0.seconds != $1.seconds ? $0.seconds < $1.seconds : $0.date < $1.date }) else {
                return RunBest(distance: distance, seconds: nil, date: nil, isNew: false)
            }
            return RunBest(distance: distance, seconds: winner.seconds, date: winner.date, isNew: contains(interval, winner.date))
        }
    }

    private static func contains(_ interval: DateInterval, _ date: Date) -> Bool {
        interval.start <= date && date < interval.end
    }
}
