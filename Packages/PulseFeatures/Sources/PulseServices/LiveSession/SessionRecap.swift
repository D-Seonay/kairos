import Foundation
import PulseContent
import PulseDomain
import PulseRecoveryEngine

/// Un record battu pendant la séance, avec sa nature : « Développé couché à la barre : 72,5 kg, nouveau record de charge ».
public struct BeatenRecord: Sendable, Equatable {
    public var exerciseName: String
    public var kind: RecordKind
    public var text: String
    /// Le même texte dit en mots pour VoiceOver : « kilos » pour « kg », « maximum estimé sur une répétition » pour « 1RM estimé ».
    public var spokenText: String

    public init(exerciseName: String, kind: RecordKind, text: String, spokenText: String? = nil) {
        self.exerciseName = exerciseName
        self.kind = kind
        self.text = text
        self.spokenText = spokenText ?? text
    }

    /// Le texte sans la fin « , nouveau record… » : « Développé couché à la barre : 72,5 kg », pour une ligne déjà marquée d'un
    /// trophée (la carte de partage).
    public var headline: String {
        guard let range = text.range(of: String(localized: ", nouveau record", bundle: .module), options: .backwards) else {
            return text
        }
        return String(text[..<range.lowerBound])
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
    /// Les exercices de la séance sur un plateau que cette séance confirme (elle compte et ne fait pas mieux).
    public var plateaus: [PlateauNotice] = []
    let load: LoadHistory

    static let defaultRPE = 7

    /// « Charge de la séance : 55 min × 7 = 385. », suivi du ratio aigu / chronique quand l'historique en donne un.
    public func loadSentence(rpe: Int) -> String {
        let sentence = String(localized: "Charge de la séance : \(durationMinutes) min × \(rpe) = \(durationMinutes * rpe).",
                              bundle: .module)
        let draft = WorkoutSession(startedAt: startedAt, endedAt: endedAt, kind: .strength, source: .pulse, status: .completed,
                                   title: title, overallRPE: Double(rpe), durationMinutes: Double(durationMinutes),
                                   createdAt: endedAt, updatedAt: endedAt)
        guard let acwr = TrainingLoad.acwr(sessions: load.sessions + [draft], historyStart: load.historyStart,
                                           now: endedAt, calendar: load.calendar) else { return sentence }
        let ratio = LiveSessionText.decimal(acwr.ratio)
        return sentence + " " + String(localized: "Ratio aigu / chronique après la séance : \(ratio).", bundle: .module)
    }

    public static func == (lhs: SessionRecap, rhs: SessionRecap) -> Bool {
        lhs.title == rhs.title && lhs.startedAt == rhs.startedAt && lhs.endedAt == rhs.endedAt
            && lhs.durationMinutes == rhs.durationMinutes && lhs.tonnageKg == rhs.tonnageKg && lhs.workingSets == rhs.workingSets
            && lhs.beatenRecords == rhs.beatenRecords && lhs.muscleWeights == rhs.muscleWeights
            && lhs.setsPerGroup.elementsEqual(rhs.setsPerGroup, by: { $0.0 == $1.0 && $0.1 == $1.1 })
            && lhs.suggestedRPE == rhs.suggestedRPE && lhs.plateaus == rhs.plateaus && lhs.load == rhs.load
    }
}

/// Un plateau signalé au récap : l'exercice, le calcul et une variante du même plan de mouvement à proposer.
public struct PlateauNotice: Sendable, Equatable {
    public var exerciseName: String
    public var plateau: ExercisePlateau
    /// Une variante faisable avec le matériel du profil (`ReplacementPlanner`), absente de la séance ; `nil` sans variante.
    public var variantName: String?

    public init(exerciseName: String, plateau: ExercisePlateau, variantName: String?) {
        self.exerciseName = exerciseName
        self.plateau = plateau
        self.variantName = variantName
    }
}

/// Ce que le ratio aigu / chronique lit : les séances des 28 derniers jours, et le début de l'historique
/// (`TrainingLoad.historyStart`, lu sur toutes les séances), qui décide s'il y a assez de recul.
struct LoadHistory: Sendable, Equatable {
    var sessions: [WorkoutSession]
    var historyStart: Date?
    var calendar: Calendar

    init(sessions: [WorkoutSession], onboardingCompletedAt: Date?, endedAt: Date, calendar: Calendar) {
        let windowStart = calendar.date(byAdding: .day, value: -LoadCalculator.requiredHistoryDays,
                                        to: calendar.startOfDay(for: endedAt)) ?? endedAt
        self.sessions = sessions.filter { $0.startedAt >= windowStart }
        historyStart = TrainingLoad.historyStart(sessions: sessions, onboardingCompletedAt: onboardingCompletedAt)
        self.calendar = calendar
    }
}

extension SessionRecap {
    /// Le bilan de `draft`, la séance telle qu'elle serait enregistrée, sur `history` (les autres séances enregistrées).
    static func make(draft: WorkoutSession, history: [WorkoutSession], directory: ExerciseDirectory,
                     loadKind: (ExerciseReference) -> LoadKind, load: LoadHistory, profile: UserProfile? = nil) -> SessionRecap {
        let working = draft.sets.filter { $0.setType != .warmup }
        let rpes = working.compactMap(\.rpe)
        let suggested = rpes.isEmpty ? defaultRPE : Int((rpes.reduce(0, +) / Double(rpes.count)).rounded())
        let beaten = beatenPersonalRecords(of: draft, history: history, loadKind: loadKind)
        return SessionRecap(
            title: draft.title, startedAt: draft.startedAt, endedAt: draft.endedAt ?? draft.updatedAt,
            durationMinutes: Int(draft.durationMinutes ?? 0), tonnageKg: draft.tonnageKg, workingSets: working.count,
            beatenRecords: beaten.map { record in
                BeatenRecord(exerciseName: record.exerciseName, kind: record.kind,
                             text: text(of: record, loadKind: loadKind(record.exercise)),
                             spokenText: spokenText(of: record, loadKind: loadKind(record.exercise)))
            },
            muscleWeights: muscleWeights(of: working, directory: directory),
            setsPerGroup: setsPerGroup(of: working, directory: directory),
            suggestedRPE: min(10, max(1, suggested)),
            plateaus: plateaus(of: draft, history: history, directory: directory, loadKind: loadKind, profile: profile, load: load,
                               skipping: Set(beaten.map(\.exercise))),
            load: load)
    }

    // swiftlint:disable function_parameter_count
    /// Les plateaus que la séance confirme : la dernière séance comptée de l'exercice est celle-ci. Un jour de fatigue ou de
    /// décharge ne compte pas : il ne signale rien. Un exercice qui bat un record dans la séance (`skipping`) n'en a pas : le
    /// récap ne dit pas « record » et « plateau » pour le même exercice.
    private static func plateaus(of draft: WorkoutSession, history: [WorkoutSession], directory: ExerciseDirectory,
                                 loadKind: (ExerciseReference) -> LoadKind, profile: UserProfile?, load: LoadHistory,
                                 skipping: Set<ExerciseReference>) -> [PlateauNotice] {
        let working = draft.sets.filter { $0.setType != .warmup }
        var exercises: [ExerciseReference] = []
        for set in working where !exercises.contains(set.exercise) { exercises.append(set.exercise) }
        let sessions = history + [draft]
        let now = draft.endedAt ?? draft.updatedAt
        return exercises.compactMap { reference in
            guard !skipping.contains(reference),
                  let plateau = PlateauDetector.plateau(for: reference, in: sessions, loadKind: loadKind(reference), now: now,
                                                        calendar: load.calendar),
                  plateau.lastDate == draft.startedAt else { return nil }
            let name = directory.info(reference)?.name ?? working.first { $0.exercise == reference }?.exerciseName ?? ""
            let variant = ReplacementPlanner.alternatives(for: reference, directory: directory, profile: profile,
                                                          excluding: Set(exercises)).first
            return PlateauNotice(exerciseName: name, plateau: plateau, variantName: variant?.name)
        }
    }
    // swiftlint:enable function_parameter_count

    /// Les records de l'historique et de la séance, recalculés ensemble : seules les séries de la séance qui battent un record
    /// déjà établi comptent, pas un premier passage sur un exercice.
    private static func beatenPersonalRecords(of draft: WorkoutSession, history: [WorkoutSession],
                                              loadKind: (ExerciseReference) -> LoadKind) -> [PersonalRecord] {
        let result = RecordBook.compute(sessions: history + [draft], loadKind: loadKind, now: draft.updatedAt)
        return result.records.filter { $0.sessionID == draft.id && $0.setID.map(result.recordSetIDs.contains) == true }
    }

    /// « … : 72,5 kg, nouveau record de charge », « … : 1RM estimé 84 kg, nouveau record »,
    /// « … : 8 répétitions à 70 kg, nouveau record ».
    private static func text(of record: PersonalRecord, loadKind: LoadKind) -> String {
        let name = record.exerciseName
        switch record.kind {
        case .maxWeight:
            let weight = LiveSessionText.weight(record.value)
            return String(localized: "\(name) : \(weight) \(PulseUnits.current.weightSymbol), nouveau record de charge", bundle: .module)
        case .estimatedOneRepMax:
            let estimate = LiveSessionText.decimal((PulseUnits.current.displayedWeight(kilograms: record.value) * 10).rounded() / 10)
            return String(localized: "\(name) : 1RM estimé \(estimate) \(PulseUnits.current.weightSymbol), nouveau record", bundle: .module)
        case .repsAtWeight:
            let reps = Int(record.value)
            let weightKg = record.weightKg ?? 0
            let count = LiveSessionText.repetitions(reps)
            if loadKind != .external, weightKg <= 0 {
                return String(localized: "\(name) : \(count) au poids du corps, nouveau record", bundle: .module)
            }
            // Le lest et l'aide s'écrivent comme dans la colonne « précédent » : « +10 », « −20 ».
            let sign = switch loadKind {
            case .external: ""
            case .bodyweight: "+"
            case .assisted: "−"
            }
            let weight = sign + LiveSessionText.weight(weightKg)
            return String(localized: "\(name) : \(count) à \(weight) \(PulseUnits.current.weightSymbol), nouveau record", bundle: .module)
        }
    }

    /// Le texte d'un record dit en mots : « … : 72,5 kilos, nouveau record de charge », « … : maximum estimé sur une répétition
    /// 84 kilos, nouveau record », « … : 8 répétitions à 70 kilos, nouveau record », « … : 8 répétitions avec un lest de 10 kilos,
    /// nouveau record ».
    static func spokenText(of record: PersonalRecord, loadKind: LoadKind) -> String {
        let name = record.exerciseName
        switch record.kind {
        case .maxWeight:
            let weight = LiveSessionText.kilosSpoken(record.value)
            return String(localized: "\(name) : \(weight), nouveau record de charge", bundle: .module)
        case .estimatedOneRepMax:
            let estimate = LiveSessionText.kilosSpoken((record.value * 10).rounded() / 10)
            return String(localized: "\(name) : maximum estimé sur une répétition \(estimate), nouveau record", bundle: .module)
        case .repsAtWeight:
            let reps = Int(record.value)
            let count = LiveSessionText.repetitions(reps)
            let weightKg = record.weightKg ?? 0
            if loadKind != .external, weightKg <= 0 {
                return String(localized: "\(name) : \(count) au poids du corps, nouveau record", bundle: .module)
            }
            let weight = LiveSessionText.kilosSpoken(weightKg)
            return switch loadKind {
            case .external: String(localized: "\(name) : \(count) à \(weight), nouveau record", bundle: .module)
            case .bodyweight: String(localized: "\(name) : \(count) avec un lest de \(weight), nouveau record", bundle: .module)
            case .assisted: String(localized: "\(name) : \(count) avec une assistance de \(weight), nouveau record", bundle: .module)
            }
        }
    }

    /// 1 par série pour un muscle principal, 0,5 pour un secondaire ; un exercice inconnu de l'annuaire est ignoré.
    static func muscleWeights(of sets: [WorkoutSet], directory: ExerciseDirectory) -> [Muscle: Double] {
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
