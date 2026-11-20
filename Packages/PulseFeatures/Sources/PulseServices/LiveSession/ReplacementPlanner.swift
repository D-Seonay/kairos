import Foundation
import PulseDomain
import PulseRecoveryEngine

/// Le remplacement d'un exercice en séance (spec M4 §8.3, §19.3) : les alternatives à proposer, puis l'exercice remplaçant
/// prêt à saisir. Pur : l'historique, les réglages et le profil sont lus avant l'appel.
public enum ReplacementPlanner {
    public static let alternativeCount = 3
    static let defaultReps = 8...12

    /// Jusqu'à trois alternatives : celles que le contenu donne pour l'exercice, puis d'autres exercices du même plan de
    /// mouvement, toutes faisables avec le matériel du profil et sans zone à risque qu'il déclare douloureuse. Les exercices
    /// déjà dans la séance sont écartés.
    public static func alternatives(for reference: ExerciseReference, directory: ExerciseDirectory, profile: UserProfile?,
                                    excluding: Set<ExerciseReference>) -> [ExerciseInfo] {
        guard let original = directory.info(reference) else { return [] }
        let allowed = (profile?.equipmentAccess ?? .fullGym).allowedEquipment
        let pains = Set(profile?.painAreas ?? [])
        func isSuitable(_ info: ExerciseInfo) -> Bool {
            info.reference != reference && !excluding.contains(info.reference) && info.isActive
                && allowed.contains(info.equipment) && (info.content?.riskAreas ?? []).allSatisfy { !pains.contains($0) }
        }
        let listed = (original.content?.alternatives ?? []).compactMap { directory.info(.content(id: $0)) }
        let samePattern = directory.active.filter { $0.pattern == original.pattern }
            .sorted { ($0.isCompound == original.isCompound ? 0 : 1, $0.name) < ($1.isCompound == original.isCompound ? 0 : 1, $1.name) }
        var picked: [ExerciseInfo] = []
        for info in listed + samePattern where isSuitable(info) && !picked.contains(where: { $0.reference == info.reference }) {
            picked.append(info)
            if picked.count == alternativeCount { break }
        }
        return picked
    }

    // swiftlint:disable function_parameter_count
    /// Les séries restantes de `exercise` passées à `reference` : autant de séries de travail que celles qui n'étaient pas
    /// validées, la même fourchette de répétitions, le même repos et le même plafond de RPE. Avec un historique, les valeurs
    /// proposées viennent de lui (§8.1) ; sans, de la charge équivalente au 1RM estimé de l'exercice remplacé, affichée comme
    /// une proposition à ajuster. `nil` quand il ne reste aucune série à remplacer.
    public static func replacement(of exercise: LiveExercise, with reference: ExerciseReference, reason: ReplacementReason,
                                   directory: ExerciseDirectory, history: [WorkoutSet], settings: ExerciseSettings?,
                                   profile: UserProfile?, policy: ProgressionPolicy) -> LiveExercise? {
        let remaining = exercise.sets.filter { $0.setType != .warmup && $0.completedAt == nil }
        guard !remaining.isEmpty else { return nil }
        let reps = remaining.compactMap { $0.proposed.reps ?? $0.reps }
        let range = (reps.min() ?? defaultReps.lowerBound)...(reps.max() ?? defaultReps.upperBound)
        let routineExercise = RoutineExercise(order: 0, exercise: reference, sets: remaining.count, repsMin: range.lowerBound,
                                              repsMax: range.upperBound, targetRPE: exercise.rpeCap ?? 8,
                                              restSeconds: exercise.restSeconds)
        var replacement = LiveSessionPlanner.exercise(
            reference, directory: directory, history: history, settings: settings, profile: profile, policy: policy,
            workedMuscles: Set(directory.info(exercise.exercise)?.primaryMuscles ?? []), routineExercise: routineExercise)
        replacement.restSeconds = exercise.restSeconds
        replacement.rpeCap = exercise.rpeCap
        replacement.supersetGroup = exercise.supersetGroup
        replacement.replacedExercise = exercise.exercise
        replacement.replacementReason = reason
        if history.isEmpty, let load = equivalentLoad(from: exercise, to: replacement, targetReps: range.upperBound,
                                                       directory: directory, profile: profile) {
            replacement.sets = replacement.sets.map { set in
                guard set.setType != .warmup else { return set }
                var estimated = set
                estimated.proposed.weightKg = load
                estimated.weightKg = load
                return estimated
            }
            replacement.dayNote = String(localized: "Remplace \(exercise.name) · charge estimée, à ajuster", bundle: .module)
        } else {
            replacement.dayNote = String(localized: "Remplace \(exercise.name)", bundle: .module)
        }
        return replacement
    }
    // swiftlint:enable function_parameter_count

    /// La charge équivalente (§8.3) : le 1RM estimé sur ce que l'exercice remplacé allait faire (première série restante),
    /// à défaut sur sa meilleure série validée, passé d'un matériel à l'autre.
    static func equivalentLoad(from original: LiveExercise, to replacement: LiveExercise, targetReps: Int,
                               directory: ExerciseDirectory, profile: UserProfile?) -> Double? {
        guard original.loadKind == .external, replacement.loadKind == .external,
              let from = directory.info(original.exercise)?.equipment,
              let toInfo = directory.info(replacement.exercise) else { return nil }
        let working = original.sets.filter { $0.setType != .warmup }
        let next = working.first { $0.completedAt == nil }
        let candidates = ([next].compactMap { $0 } + working.filter { $0.completedAt != nil })
        let oneRepMax = candidates.compactMap { set -> Double? in
            guard let weight = set.weightKg ?? set.proposed.weightKg, let reps = set.reps ?? set.proposed.reps else { return nil }
            return OneRepMax.brzycki(weightKg: weight, reps: reps)
        }.max()
        guard let oneRepMax else { return nil }
        return EquivalentLoad.estimate(oneRepMaxKg: oneRepMax, switching: (from, toInfo.equipment), targetReps: targetReps,
                                       rounding: LiveSessionPlanner.rounding(for: toInfo, profile: profile),
                                       incrementKg: replacement.incrementKg)
    }
}
