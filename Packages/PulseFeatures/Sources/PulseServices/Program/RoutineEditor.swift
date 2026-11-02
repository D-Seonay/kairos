import Foundation
import PulseDomain

/// Modifie les exercices d'un jour de routine sans l'enregistrer : chaque fonction rend une copie du jour.
/// Après chaque opération, `order` va de 0 à n−1, les groupes de super set de 1 à k, et une paire qui n'est plus
/// consécutive est défaite. Une fourchette inversée est toujours remise à l'endroit : `repRange(forSet:)` planterait.
public enum RoutineEditor {
    /// Le repos d'un exercice que l'annuaire ne connaît pas.
    static let fallbackRestSeconds = 90

    /// Ajoute `references` en fin de jour : 3 séries de 8 à 12 répétitions (30 à 60 s pour un exercice tenu), RPE 8.
    public static func add(_ references: [ExerciseReference], to day: RoutineDay, directory: ExerciseDirectory) -> RoutineDay {
        var result = day
        for reference in references {
            let info = directory.info(reference)
            let held = info?.tracksDuration ?? false
            result.exercises.append(RoutineExercise(
                order: result.exercises.count, exercise: reference, sets: 3, repsMin: held ? 30 : 8, repsMax: held ? 60 : 12,
                targetRPE: 8, restSeconds: info?.defaultRestSeconds ?? fallbackRestSeconds))
        }
        return normalized(result)
    }

    public static func move(fromOffsets offsets: IndexSet, toOffset destination: Int, in day: RoutineDay) -> RoutineDay {
        guard !offsets.isEmpty, offsets.allSatisfy({ day.exercises.indices.contains($0) }) else { return day }
        let moved = offsets.map { day.exercises[$0] }
        var remaining = day.exercises.enumerated().filter { !offsets.contains($0.offset) }.map(\.element)
        let clamped = min(max(destination, 0), day.exercises.count)
        let insertion = clamped - offsets.filter { $0 < clamped }.count
        remaining.insert(contentsOf: moved, at: insertion)
        var result = day
        result.exercises = remaining
        return normalized(result)
    }

    public static func remove(at index: Int, from day: RoutineDay) -> RoutineDay {
        guard day.exercises.indices.contains(index) else { return day }
        var result = day
        result.exercises.remove(at: index)
        return normalized(result)
    }

    /// Apparie l'exercice `index` et le suivant, ou défait leur paire. Un exercice déjà en paire n'entre pas dans une autre.
    public static func toggleSuperset(at index: Int, in day: RoutineDay) -> RoutineDay {
        guard day.exercises.indices.contains(index), day.exercises.indices.contains(index + 1) else { return day }
        var result = day
        let first = day.exercises[index].supersetGroup
        let second = day.exercises[index + 1].supersetGroup
        if let first, first == second {
            result.exercises[index].supersetGroup = nil
            result.exercises[index + 1].supersetGroup = nil
        } else if first == nil, second == nil {
            let group = (day.exercises.compactMap(\.supersetGroup).max() ?? 0) + 1
            result.exercises[index].supersetGroup = group
            result.exercises[index + 1].supersetGroup = group
        } else {
            return day
        }
        return normalized(result)
    }

    /// Fixe le nombre de séries (au moins 1) ; les fourchettes par série suivent, en répétant la dernière.
    public static func setSets(_ count: Int, at index: Int, in day: RoutineDay) -> RoutineDay {
        edit(day, at: index) { exercise in
            exercise.sets = max(1, count)
            guard var targets = exercise.setTargets else { return }
            targets = Array(targets.prefix(exercise.sets))
            let last = targets.last ?? SetTarget(repsMin: exercise.repsMin, repsMax: exercise.repsMax).ordered
            while targets.count < exercise.sets { targets.append(last) }
            exercise.setTargets = targets
            syncRange(&exercise)
        }
    }

    /// Activé, chaque série reçoit la fourchette de l'exercice ; désactivé, la fourchette de l'exercice couvre toutes les séries.
    public static func setPerSetTargets(_ enabled: Bool, at index: Int, in day: RoutineDay) -> RoutineDay {
        edit(day, at: index) { exercise in
            if enabled, exercise.setTargets == nil {
                let range = SetTarget(repsMin: exercise.repsMin, repsMax: exercise.repsMax).ordered
                exercise.setTargets = Array(repeating: range, count: exercise.sets)
                exercise.repsMin = range.repsMin
                exercise.repsMax = range.repsMax
            } else if !enabled {
                syncRange(&exercise)
                exercise.setTargets = nil
            }
        }
    }

    /// Fixe la fourchette de la série `set` (à partir de 0). Les séries suivantes qui avaient la même fourchette la prennent
    /// aussi, comme dans une montée en charge saisie de haut en bas ; celles qu'on a réglées autrement restent. L'exercice
    /// couvre le min et le max de ses séries.
    public static func updateSetTarget(_ target: SetTarget, set: Int, at index: Int, in day: RoutineDay) -> RoutineDay {
        edit(day, at: index) { exercise in
            guard let targets = exercise.setTargets, targets.indices.contains(set) else { return }
            let previous = targets[set]
            let updated = target.ordered
            exercise.setTargets = targets.enumerated().map { position, current in
                position == set || (position > set && current == previous) ? updated : current
            }
            syncRange(&exercise)
        }
    }

    /// Le jour avec `order` et les super sets remis d'aplomb.
    static func normalized(_ day: RoutineDay) -> RoutineDay {
        var result = day
        for position in result.exercises.indices { result.exercises[position].order = position }
        let groups = renumberedGroups(result.exercises.map(\.supersetGroup))
        for position in result.exercises.indices { result.exercises[position].supersetGroup = groups[position] }
        return result
    }

    /// Ne garde que les suites d'au moins deux exercices consécutifs du même groupe, numérotées de 1 à k.
    private static func renumberedGroups(_ groups: [Int?]) -> [Int?] {
        var renumbered = [Int?](repeating: nil, count: groups.count)
        var next = 1
        var start = 0
        while start < groups.count {
            var end = start + 1
            while end < groups.count, groups[end] == groups[start] { end += 1 }
            if groups[start] != nil, end - start >= 2 {
                for position in start..<end { renumbered[position] = next }
                next += 1
            }
            start = end
        }
        return renumbered
    }

    private static func edit(_ day: RoutineDay, at index: Int, _ change: (inout RoutineExercise) -> Void) -> RoutineDay {
        guard day.exercises.indices.contains(index) else { return day }
        var result = day
        change(&result.exercises[index])
        return result
    }

    /// Aligne la fourchette de l'exercice sur le min et le max de ses séries.
    private static func syncRange(_ exercise: inout RoutineExercise) {
        guard let targets = exercise.setTargets, let low = targets.map(\.repsMin).min(), let high = targets.map(\.repsMax).max() else {
            return
        }
        exercise.repsMin = low
        exercise.repsMax = high
    }
}

extension SetTarget {
    /// La même fourchette, bornes dans l'ordre.
    var ordered: SetTarget {
        SetTarget(repsMin: min(repsMin, repsMax), repsMax: max(repsMin, repsMax))
    }
}
