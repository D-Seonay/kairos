import Foundation
import PulseDomain
import PulseRecoveryEngine

/// Transforme un lancement en séance prête à saisir : charges proposées série par série, « précédent », « Dernière fois »
/// et la ligne du jour (spec M4 §8.1, §14.3). Pure : l'historique et les réglages sont lus avant l'appel.
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
    }

    // swiftlint:disable function_parameter_count
    public static func session(for launch: SessionLaunch, directory: ExerciseDirectory,
                               history: [ExerciseReference: [WorkoutSet]], settings: [ExerciseReference: ExerciseSettings],
                               profile: UserProfile?, now: Date) -> LiveSession {
        let context = Context(directory: directory, profile: profile, policy: launch.policy)
        let planned = Dictionary((launch.plannedDay?.exercises ?? []).map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var applied = launch.applied
        var exercises: [LiveExercise] = []
        for routineExercise in (launch.day?.exercises ?? []).sorted(by: { $0.order < $1.order }) {
            let reference = routineExercise.exercise
            let built = build(routineExercise, planned: planned[routineExercise.id], lastSets: history[reference] ?? [],
                              settings: settings[reference], context: context)
            exercises.append(built.exercise)
            if let adjustment = built.loadAdjustment { applied.append(adjustment) }
        }
        return LiveSession(title: launch.title, startedAt: now, lastActionAt: now, programID: launch.programID,
                           routineDayID: launch.day?.id, appliedAdjustments: applied, refusedAdjustments: launch.refused,
                           exercises: exercises)
    }
    // swiftlint:enable function_parameter_count

    // swiftlint:disable function_parameter_count
    /// Un exercice ajouté en séance : 3 séries de 8 à 12 répétitions (30 à 60 s s'il est tenu), au repos par défaut de
    /// l'exercice, sinon à celui du profil.
    public static func exercise(_ reference: ExerciseReference, directory: ExerciseDirectory, history: [WorkoutSet],
                                settings: ExerciseSettings?, profile: UserProfile?, policy: ProgressionPolicy) -> LiveExercise {
        let info = directory.info(reference)
        let range = info?.tracksDuration == true ? addedHoldRange : addedRepRange
        let restSeconds = info?.defaultRestSeconds ?? profile?.defaultRestSeconds ?? fallbackRestSeconds
        let routineExercise = RoutineExercise(order: 0, exercise: reference, sets: addedSetCount, repsMin: range.lowerBound,
                                              repsMax: range.upperBound, targetRPE: addedTargetRPE, restSeconds: restSeconds)
        let context = Context(directory: directory, profile: profile, policy: policy)
        return build(routineExercise, planned: nil, lastSets: history, settings: settings, context: context).exercise
    }
    // swiftlint:enable function_parameter_count

    private typealias Built = (exercise: LiveExercise, loadAdjustment: SessionAdjustment?)

    private static func build(_ routineExercise: RoutineExercise, planned: RoutineExercise?, lastSets: [WorkoutSet],
                              settings: ExerciseSettings?, context: Context) -> Built {
        let info = context.directory.info(routineExercise.exercise)
        let name = info?.name ?? String(localized: "Exercice inconnu", bundle: .module)
        let loadKind = info?.loadKind ?? .external
        let tracksDuration = info?.tracksDuration ?? false
        let incrementKg = info.map { IncrementResolver.increment(for: $0, settings: settings, profile: context.profile) }
            ?? settings?.incrementKg ?? fallbackIncrementKg
        let proposal = LoadProgression.propose(exercise: routineExercise, name: name, loadKind: loadKind,
                                               tracksDuration: tracksDuration, lastSets: lastSets, incrementKg: incrementKg,
                                               rounding: rounding(for: info, profile: context.profile), policy: context.policy)
        let sets = proposal.sets.enumerated().map { index, proposed in
            let before = index < lastSets.count ? lastSets[index] : nil
            return LiveSet(proposed: proposed, previous: LiveSessionText.previous(before, loadKind: loadKind,
                                                                                  tracksDuration: tracksDuration))
        }
        let lowered = planned.map { routineExercise.targetRPE < $0.targetRPE } ?? false
        let exercise = LiveExercise(
            exercise: routineExercise.exercise, name: name, loadKind: loadKind, tracksDuration: tracksDuration,
            isBarbell: info?.equipment == .barbell, incrementKg: incrementKg, supersetGroup: routineExercise.supersetGroup,
            restSeconds: routineExercise.restSeconds, rpeCap: lowered ? routineExercise.targetRPE : nil,
            dayNote: LiveSessionText.dayNote(loadAdjustment: proposal.loadAdjustment, hasHistory: !lastSets.isEmpty,
                                             policy: context.policy, planned: planned, adjusted: routineExercise),
            lastTimeText: LiveSessionText.lastTime(lastSets, loadKind: loadKind, tracksDuration: tracksDuration), sets: sets)
        return (exercise, proposal.loadAdjustment)
    }

    /// Aux disques déclarés sur une barre, à l'incrément ailleurs ou sans disques connus.
    private static func rounding(for info: ExerciseInfo?, profile: UserProfile?) -> WeightRounding {
        guard info?.equipment == .barbell, let profile, let smallest = profile.availablePlatesKg.filter({ $0 > 0 }).min() else {
            return .increment
        }
        return .plates(barKg: profile.barWeightKg, smallestPlateKg: smallest)
    }
}
