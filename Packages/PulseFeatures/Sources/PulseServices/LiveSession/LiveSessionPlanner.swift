import Foundation
import PulseDomain
import PulseRecoveryEngine

/// Transforme un lancement en séance prête à saisir : séries d'échauffement, charges proposées série par série, « précédent »,
/// « Dernière fois » et la ligne du jour (spec M4 §8.1, §8.3, §14.3). Pure : l'historique et les réglages sont lus avant l'appel.
public enum LiveSessionPlanner {
    /// L'incrément d'un exercice que l'annuaire ne connaît pas, sans réglage.
    static let fallbackIncrementKg = 2.5
    static let fallbackRestSeconds = 90
    static let addedSetCount = 3
    static let addedRepRange = 8...12
    static let addedHoldRange = 30...60
    static let addedTargetRPE = 8.0

    private struct Context {
        var directory: ExerciseDirectory
        var profile: UserProfile?
        var policy: ProgressionPolicy
        /// Le facteur des charges externes proposées : 0,9 pendant une semaine de décharge.
        var loadFactor = 1.0
    }

    // swiftlint:disable function_parameter_count
    public static func session(for launch: SessionLaunch, directory: ExerciseDirectory,
                               history: [ExerciseReference: [WorkoutSet]], settings: [ExerciseReference: ExerciseSettings],
                               profile: UserProfile?, now: Date) -> LiveSession {
        let context = Context(directory: directory, profile: profile, policy: launch.policy, loadFactor: launch.loadFactor)
        let planned = Dictionary((launch.plannedDay?.exercises ?? []).map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var applied = launch.applied
        var exercises: [LiveExercise] = []
        // Les muscles principaux déjà travaillés : un exercice qui en reprend un n'est pas échauffé une seconde fois.
        var worked: Set<Muscle> = []
        for routineExercise in (launch.day?.exercises ?? []).sorted(by: { $0.order < $1.order }) {
            let reference = routineExercise.exercise
            let built = build(routineExercise, planned: planned[routineExercise.id], lastSets: history[reference] ?? [],
                              settings: settings[reference], context: context, workedMuscles: worked)
            exercises.append(built.exercise)
            worked.formUnion(directory.info(reference)?.primaryMuscles ?? [])
            if let adjustment = built.loadAdjustment { applied.append(adjustment) }
        }
        return LiveSession(title: launch.title, startedAt: launch.past?.start ?? now, lastActionAt: now,
                           programID: launch.programID, routineDayID: launch.day?.id, appliedAdjustments: applied,
                           refusedAdjustments: launch.refused, policy: launch.policy, exercises: exercises,
                           pastEndedAt: launch.past?.end, loadFactor: launch.loadFactor == 1 ? nil : launch.loadFactor,
                           deloadStartedAt: launch.historyLimit)
    }
    // swiftlint:enable function_parameter_count

    // swiftlint:disable function_parameter_count
    /// Un exercice ajouté en séance : 3 séries de 8 à 12 répétitions (30 à 60 s s'il est tenu), au repos par défaut de
    /// l'exercice, sinon à celui du profil. `workedMuscles` : les muscles principaux des exercices déjà dans la séance.
    /// `routineExercise` remplace ces séries par défaut (le remplacement reprend celles de l'exercice remplacé). `loadFactor`
    /// baisse les charges externes proposées comme au lancement : 0,9 dans une séance lancée en décharge.
    public static func exercise(_ reference: ExerciseReference, directory: ExerciseDirectory, history: [WorkoutSet],
                                settings: ExerciseSettings?, profile: UserProfile?, policy: ProgressionPolicy,
                                workedMuscles: Set<Muscle> = [], routineExercise: RoutineExercise? = nil,
                                loadFactor: Double = 1) -> LiveExercise {
        let info = directory.info(reference)
        let range = info?.tracksDuration == true ? addedHoldRange : addedRepRange
        let restSeconds = info?.defaultRestSeconds ?? profile?.defaultRestSeconds ?? fallbackRestSeconds
        let routineExercise = routineExercise ?? RoutineExercise(
            order: 0, exercise: reference, sets: addedSetCount, repsMin: range.lowerBound, repsMax: range.upperBound,
            targetRPE: addedTargetRPE, restSeconds: restSeconds)
        let context = Context(directory: directory, profile: profile, policy: policy, loadFactor: loadFactor)
        return build(routineExercise, planned: nil, lastSets: history, settings: settings, context: context,
                     workedMuscles: workedMuscles).exercise
    }
    // swiftlint:enable function_parameter_count

    private typealias Built = (exercise: LiveExercise, loadAdjustment: SessionAdjustment?)

    // swiftlint:disable:next function_parameter_count
    private static func build(_ routineExercise: RoutineExercise, planned: RoutineExercise?, lastSets: [WorkoutSet],
                              settings: ExerciseSettings?, context: Context, workedMuscles: Set<Muscle>) -> Built {
        let info = context.directory.info(routineExercise.exercise)
        let name = info?.name ?? String(localized: "Exercice inconnu", bundle: .module)
        let loadKind = info?.loadKind ?? .external
        let tracksDuration = info?.tracksDuration ?? false
        let incrementKg = info.map { IncrementResolver.increment(for: $0, settings: settings, profile: context.profile) }
            ?? settings?.incrementKg ?? fallbackIncrementKg
        let rounding = rounding(for: info, profile: context.profile)
        let proposal = LoadProgression.propose(exercise: routineExercise, name: name, loadKind: loadKind,
                                               tracksDuration: tracksDuration, lastSets: lastSets, incrementKg: incrementKg,
                                               rounding: rounding, policy: context.policy)
        let proposedSets = loadKind == .external ? scaled(proposal.sets, by: context.loadFactor, increment: incrementKg,
                                                           rounding: rounding) : proposal.sets
        let working = proposedSets.enumerated().map { index, proposed in
            let before = index < lastSets.count ? lastSets[index] : nil
            return LiveSet(proposed: proposed,
                           previous: LiveSessionText.previous(before, loadKind: loadKind, tracksDuration: tracksDuration),
                           previousSpoken: LiveSessionText.previousSpoken(before, loadKind: loadKind,
                                                                          tracksDuration: tracksDuration))
        }
        let primaryMuscles = Set(info?.primaryMuscles ?? [])
        let warms = loadKind == .external && !tracksDuration && WarmupPlanner.isEligible(
            autoWarmupEnabled: context.profile?.autoWarmupEnabled ?? false, isCompound: info?.isCompound ?? false,
            warmupSetCount: settings?.warmupSetCount, primaryMuscleAlreadyWorked: !primaryMuscles.isDisjoint(with: workedMuscles))
        let warmupPlan = warms ? LiveWarmupPlan(rounding: rounding, maxCount: settings?.warmupSetCount) : nil
        let sets = LiveSessionPlanner.warmupSets(firstWorkingKg: working.first?.proposed.weightKg, plan: warmupPlan,
                                                 incrementKg: incrementKg) + working
        let lowered = planned.map { routineExercise.targetRPE < $0.targetRPE } ?? false
        let exercise = LiveExercise(
            exercise: routineExercise.exercise, name: name, loadKind: loadKind, tracksDuration: tracksDuration,
            isBarbell: info?.equipment == .barbell, incrementKg: incrementKg, supersetGroup: routineExercise.supersetGroup,
            restSeconds: routineExercise.restSeconds, rpeCap: lowered ? routineExercise.targetRPE : nil,
            dayNote: LiveSessionText.dayNote(loadAdjustment: proposal.loadAdjustment, hasHistory: !lastSets.isEmpty,
                                             policy: context.policy, planned: planned, adjusted: routineExercise),
            lastTimeText: LiveSessionText.lastTime(lastSets, loadKind: loadKind, tracksDuration: tracksDuration),
            lastTimeSpoken: LiveSessionText.lastTimeSpoken(lastSets, loadKind: loadKind, tracksDuration: tracksDuration),
            sets: sets,
            warmupPlan: warmupPlan)
        return (exercise, proposal.loadAdjustment)
    }

    /// Les séries d'échauffement proposées avant une première série de travail à `firstWorkingKg` ; aucune sans plan ou sans
    /// charge de travail connue (un exercice sans historique).
    static func warmupSets(firstWorkingKg: Double?, plan: LiveWarmupPlan?, incrementKg: Double) -> [LiveSet] {
        guard let plan, let firstWorkingKg else { return [] }
        return WarmupPlanner.sets(firstWorkingKg: firstWorkingKg, rounding: plan.rounding, incrementKg: incrementKg,
                                  maxCount: plan.maxCount).map { warmup in
            let proposed = ProposedSet(weightKg: warmup.weightKg, reps: warmup.reps)
            return LiveSet(setType: .warmup, proposed: proposed, weightKg: warmup.weightKg, reps: warmup.reps)
        }
    }

    /// Les charges de `sets` multipliées par `factor`, arrondies au plus près comme les autres charges ; inchangées à 1.
    static func scaled(_ sets: [ProposedSet], by factor: Double, increment: Double, rounding: WeightRounding) -> [ProposedSet] {
        guard factor != 1 else { return sets }
        return sets.map { set in
            var lowered = set
            lowered.weightKg = set.weightKg.map { PlateRounding.nearestLoad($0 * factor, increment: increment, rounding: rounding) }
            return lowered
        }
    }

    /// Aux disques déclarés sur une barre, à l'incrément ailleurs ou sans disques connus.
    static func rounding(for info: ExerciseInfo?, profile: UserProfile?) -> WeightRounding {
        guard info?.equipment == .barbell, let profile, let smallest = profile.availablePlatesKg.filter({ $0 > 0 }).min() else {
            return .increment
        }
        return .plates(barKg: profile.barWeightKg, smallestPlateKg: smallest)
    }
}
