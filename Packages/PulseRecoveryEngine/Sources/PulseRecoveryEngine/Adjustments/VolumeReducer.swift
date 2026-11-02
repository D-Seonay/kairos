import PulseDomain

/// Retire environ 20 % des séries d'une séance de musculation, en gardant l'ordre et l'identité des exercices.
/// Les membres d'un même super set perdent leurs séries ensemble (spec M3 §9.3).
/// Chaque série retirée emporte sa cible de répétitions : la dernière d'abord.
enum VolumeReducer {
    struct Result: Equatable {
        var exercises: [RoutineExercise]
        var removedSets: Int
    }

    static func reduce(_ exercises: [RoutineExercise], by ratio: Double) -> Result {
        let total = exercises.reduce(0) { $0 + $1.sets }
        let target = Int((Double(total) * ratio).rounded())
        let units = makeUnits(exercises)
        var remaining = exercises
        var removed = 0
        var removedThisRound = true
        while removed < target && removedThisRound {
            removedThisRound = false
            for unit in orderedUnits(units, in: remaining) {
                let reducible = unit.allSatisfy { remaining[$0].sets > 1 }
                guard reducible, removed + unit.count <= target else { continue }
                for index in unit {
                    remaining[index].sets -= 1
                    _ = remaining[index].setTargets?.popLast()
                }
                removed += unit.count
                removedThisRound = true
            }
        }
        return Result(exercises: remaining, removedSets: removed)
    }

    /// Un exercice seul, ou les membres d'un même super set, dans l'ordre de première apparition.
    private static func makeUnits(_ exercises: [RoutineExercise]) -> [[Int]] {
        var units: [[Int]] = []
        var unitByGroup: [Int: Int] = [:]
        for (index, exercise) in exercises.enumerated() {
            if let group = exercise.supersetGroup, let unitIndex = unitByGroup[group] {
                units[unitIndex].append(index)
            } else {
                if let group = exercise.supersetGroup { unitByGroup[group] = units.count }
                units.append([index])
            }
        }
        return units
    }

    /// Séries décroissantes (une unité compte le maximum de ses membres), puis ordre dans la séance.
    private static func orderedUnits(_ units: [[Int]], in exercises: [RoutineExercise]) -> [[Int]] {
        let maxSets: [Int] = units.map { unit in unit.map { exercises[$0].sets }.max() ?? 0 }
        let positions: [Int] = units.indices.sorted { lhs, rhs in
            maxSets[lhs] != maxSets[rhs] ? maxSets[lhs] > maxSets[rhs] : lhs < rhs
        }
        return positions.map { units[$0] }
    }
}
