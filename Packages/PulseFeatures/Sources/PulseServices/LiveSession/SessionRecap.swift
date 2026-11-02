import Foundation
import PulseContent
import PulseDomain
import PulseRecoveryEngine

/// Un record battu pendant la séance, avec sa nature : « Développé couché à la barre : 72,5 kg, nouveau record de charge ».
public struct BeatenRecord: Sendable, Equatable {
    public var exerciseName: String
    public var kind: RecordKind
    public var text: String

    public init(exerciseName: String, kind: RecordKind, text: String) {
        self.exerciseName = exerciseName
        self.kind = kind
        self.text = text
    }
}

/// Le bilan de fin de séance (spec M4 §17) : durée, tonnage, séries de travail, records battus, muscles travaillés et RPE
/// pré-placé. Il garde l'historique récent de charge pour dire, quel que soit le RPE choisi, le ratio aigu / chronique d'après.
public struct SessionRecap: Sendable, Equatable {
    public var title: String
    public var startedAt: Date
    public var endedAt: Date
    public var durationMinutes: Int
    public var tonnageKg: Double
    /// Les séries validées hors échauffement.
    public var workingSets: Int
    public var beatenRecords: [BeatenRecord]
    /// 1 par série de travail pour un muscle principal, 0,5 pour un secondaire.
    public var muscleWeights: [Muscle: Double]
    /// Les séries de travail par groupe de l'exercice, du plus travaillé au moins travaillé.
    public var setsPerGroup: [(MuscleGroup, Int)]
    /// La moyenne arrondie des RPE de série, sinon 7.
    public var suggestedRPE: Int
    let load: LoadHistory

    static let defaultRPE = 7

    /// « Charge de la séance : 55 min × 7 = 385. », suivi du ratio aigu / chronique quand l'historique en donne un.
    public func loadSentence(rpe: Int) -> String {
        let sentence = String(localized: "Charge de la séance : \(durationMinutes) min × \(rpe) = \(durationMinutes * rpe).",
                              bundle: .module)
        let draft = WorkoutSession(startedAt: startedAt, endedAt: endedAt, kind: .strength, source: .pulse, status: .completed,
                                   title: title, overallRPE: Double(rpe), durationMinutes: Double(durationMinutes),
                                   createdAt: endedAt, updatedAt: endedAt)
        guard let acwr = TrainingLoad.acwr(sessions: load.sessions + [draft], onboardingCompletedAt: load.historyStart,
                                           now: endedAt, calendar: load.calendar) else { return sentence }
        let ratio = LiveSessionText.decimal(acwr.ratio)
        return sentence + " " + String(localized: "Ratio aigu / chronique après la séance : \(ratio).", bundle: .module)
    }

    public static func == (lhs: SessionRecap, rhs: SessionRecap) -> Bool {
        lhs.title == rhs.title && lhs.startedAt == rhs.startedAt && lhs.endedAt == rhs.endedAt
            && lhs.durationMinutes == rhs.durationMinutes && lhs.tonnageKg == rhs.tonnageKg && lhs.workingSets == rhs.workingSets
            && lhs.beatenRecords == rhs.beatenRecords && lhs.muscleWeights == rhs.muscleWeights
            && lhs.setsPerGroup.elementsEqual(rhs.setsPerGroup, by: { $0.0 == $1.0 && $0.1 == $1.1 })
            && lhs.suggestedRPE == rhs.suggestedRPE && lhs.load == rhs.load
    }
}

/// Ce que le ratio aigu / chronique lit : les séances des 28 derniers jours, et le début de l'historique (fin de l'onboarding
/// ou plus ancienne séance), qui décide s'il y a assez de recul.
struct LoadHistory: Sendable, Equatable {
    var sessions: [WorkoutSession]
    var historyStart: Date?
    var calendar: Calendar

    init(sessions: [WorkoutSession], onboardingCompletedAt: Date?, endedAt: Date, calendar: Calendar) {
        let windowStart = calendar.date(byAdding: .day, value: -LoadCalculator.requiredHistoryDays,
                                        to: calendar.startOfDay(for: endedAt)) ?? endedAt
        self.sessions = sessions.filter { $0.startedAt >= windowStart }
        historyStart = ([onboardingCompletedAt] + sessions.map(\.startedAt)).compactMap { $0 }.min()
        self.calendar = calendar
    }
}

extension SessionRecap {
    /// Le bilan de `draft`, la séance telle qu'elle serait enregistrée, sur `history` (les autres séances enregistrées).
    static func make(draft: WorkoutSession, history: [WorkoutSession], directory: ExerciseDirectory,
                     loadKind: (ExerciseReference) -> LoadKind, load: LoadHistory) -> SessionRecap {
        let working = draft.sets.filter { $0.setType != .warmup }
        let rpes = working.compactMap(\.rpe)
        let suggested = rpes.isEmpty ? defaultRPE : Int((rpes.reduce(0, +) / Double(rpes.count)).rounded())
        return SessionRecap(
            title: draft.title, startedAt: draft.startedAt, endedAt: draft.endedAt ?? draft.updatedAt,
            durationMinutes: Int(draft.durationMinutes ?? 0), tonnageKg: draft.tonnageKg, workingSets: working.count,
            beatenRecords: beatenRecords(of: draft, history: history, loadKind: loadKind),
            muscleWeights: muscleWeights(of: working, directory: directory),
            setsPerGroup: setsPerGroup(of: working, directory: directory),
            suggestedRPE: min(10, max(1, suggested)), load: load)
    }

    /// Les records de l'historique et de la séance, recalculés ensemble : seules les séries de la séance qui battent un record
    /// déjà établi comptent, pas un premier passage sur un exercice.
    private static func beatenRecords(of draft: WorkoutSession, history: [WorkoutSession],
                                      loadKind: (ExerciseReference) -> LoadKind) -> [BeatenRecord] {
        let result = RecordBook.compute(sessions: history + [draft], loadKind: loadKind, now: draft.updatedAt)
        return result.records
            .filter { $0.sessionID == draft.id && $0.setID.map(result.recordSetIDs.contains) == true }
            .map { record in
                BeatenRecord(exerciseName: record.exerciseName, kind: record.kind,
                             text: text(of: record, loadKind: loadKind(record.exercise)))
            }
    }

    /// « … : 72,5 kg, nouveau record de charge », « … : 1RM estimé 84 kg, nouveau record »,
    /// « … : 8 répétitions à 70 kg, nouveau record ».
    private static func text(of record: PersonalRecord, loadKind: LoadKind) -> String {
        let name = record.exerciseName
        switch record.kind {
        case .maxWeight:
            let weight = LiveSessionText.decimal(record.value)
            return String(localized: "\(name) : \(weight) kg, nouveau record de charge", bundle: .module)
        case .estimatedOneRepMax:
            let estimate = LiveSessionText.decimal((record.value * 10).rounded() / 10)
            return String(localized: "\(name) : 1RM estimé \(estimate) kg, nouveau record", bundle: .module)
        case .repsAtWeight:
            let reps = Int(record.value)
            let weightKg = record.weightKg ?? 0
            if loadKind != .external, weightKg <= 0 {
                return String(localized: "\(name) : \(reps) répétitions au poids du corps, nouveau record", bundle: .module)
            }
            // Le lest et l'aide s'écrivent comme dans la colonne « précédent » : « +10 », « −20 ».
            let sign = switch loadKind {
            case .external: ""
            case .bodyweight: "+"
            case .assisted: "−"
            }
            let weight = sign + LiveSessionText.decimal(weightKg)
            return String(localized: "\(name) : \(reps) répétitions à \(weight) kg, nouveau record", bundle: .module)
        }
    }

    /// 1 par série pour un muscle principal, 0,5 pour un secondaire ; un exercice inconnu de l'annuaire est ignoré.
    private static func muscleWeights(of sets: [WorkoutSet], directory: ExerciseDirectory) -> [Muscle: Double] {
        var weights: [Muscle: Double] = [:]
        for set in sets {
            guard let exercise = directory.info(set.exercise) else { continue }
            for muscle in exercise.primaryMuscles { weights[muscle, default: 0] += 1 }
            for muscle in exercise.secondaryMuscles where !exercise.primaryMuscles.contains(muscle) {
                weights[muscle, default: 0] += 0.5
            }
        }
        return weights
    }

    /// Chaque série compte dans le groupe de son exercice ; à nombre égal, l'ordre de `MuscleGroup.allCases`.
    private static func setsPerGroup(of sets: [WorkoutSet], directory: ExerciseDirectory) -> [(MuscleGroup, Int)] {
        var counts: [MuscleGroup: Int] = [:]
        for set in sets {
            guard let exercise = directory.info(set.exercise) else { continue }
            counts[exercise.group, default: 0] += 1
        }
        return MuscleGroup.allCases
            .compactMap { group in counts[group].map { (group, $0) } }
            .enumerated()
            .sorted { $0.element.1 != $1.element.1 ? $0.element.1 > $1.element.1 : $0.offset < $1.offset }
            .map(\.element)
    }
}
