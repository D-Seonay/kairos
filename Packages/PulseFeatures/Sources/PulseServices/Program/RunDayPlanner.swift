import Foundation
import PulseDomain

/// Place dans la semaine type les sorties que l'onboarding propose (« 3 séances de musculation et 1 sortie »), pour que le
/// programme adopté les contienne vraiment. Tout est pur : la même semaine et la même demande donnent le même résultat.
public enum RunDayPlanner {
    /// Une sortie à poser : son jour (0 = lundi), son type, et si elle prend la place d'une séance de musculation.
    public struct Placement: Sendable, Equatable {
        public var weekdayIndex: Int
        public var type: RunType
        public var replacesStrength: Bool

        public init(weekdayIndex: Int, type: RunType, replacesStrength: Bool) {
            self.weekdayIndex = weekdayIndex
            self.type = type
            self.replacesStrength = replacesStrength
        }
    }

    /// Les sorties que le curseur demande : les jours que la musculation, `round(jours × (1 − focus))`, ne prend pas.
    public static func requestedRuns(focus: Double, daysPerWeek: Int) -> Int {
        let days = max(0, daysPerWeek)
        let strength = min(days, max(0, Int((Double(days) * (1 - focus)).rounded())))
        return days - strength
    }

    /// Où poser `count` sorties de plus dans `week` (lundi à dimanche, `nil` pour un repos).
    ///
    /// - Un jour libre d'abord, jamais un repos obligatoire. Parmi les jours libres, ceux qui ne suivent pas une séance de
    ///   jambes lourde (`HeavyLegs`, comme la règle anti-interférence) ; à défaut ceux qui suivent une séance de jambes moins
    ///   chargée ; le lendemain de la plus lourde seulement s'il ne reste que lui. La semaine se répète : lundi suit dimanche.
    /// - Avec deux sorties ou plus dans la semaine, une seule est longue, le plus tard possible dans la semaine, et seulement
    ///   un jour qui ne suit pas des jambes lourdes : la règle anti-interférence la déplacerait sinon chaque semaine. Les
    ///   autres sont faciles, le plus loin possible des courses déjà là. Une sortie seule est facile.
    /// - Sans jour libre, la sortie prend le jour de la séance de musculation la plus légère (le moins de séries) plutôt que
    ///   de disparaître. Quand il ne reste ni jour libre ni séance à remplacer, plus rien n'est posé.
    public static func placements(adding count: Int, to week: [RoutineDay?], restWeekdays: [Weekday],
                                  directory: ExerciseDirectory) -> [Placement] {
        guard count > 0 else { return [] }
        var draft = Draft(week: week, restWeekdays: restWeekdays, directory: directory)
        let total = draft.runIndices.count + count
        var placements: [Placement] = []
        if total >= 2, !draft.hasLongRun, let index = draft.longRunDay() {
            draft.markRun(at: index)
            placements.append(Placement(weekdayIndex: index, type: .long, replacesStrength: false))
        }
        while placements.count < count {
            if let index = draft.easyRunDay() {
                draft.markRun(at: index)
                placements.append(Placement(weekdayIndex: index, type: .easy, replacesStrength: false))
            } else if let index = draft.lightestStrengthDay() {
                draft.markRun(at: index)
                placements.append(Placement(weekdayIndex: index, type: .easy, replacesStrength: true))
            } else {
                break
            }
        }
        return placements
    }

    /// Le programme dont la semaine compte `runs` sorties : celles qu'il a déjà comptent et ne sont jamais retirées, les
    /// manquantes sont posées par `placements`. Les sorties faciles ajoutées partagent un même jour de course (celui du
    /// programme s'il en a un), comme une routine placée deux fois dans la semaine. Une séance de musculation remplacée
    /// quitte la semaine mais reste une routine du programme.
    public static func adding(runs: Int, to program: Program, restWeekdays: [Weekday], directory: ExerciseDirectory) -> Program {
        let count = Weekday.allCases.count
        let layout = Array((program.weekLayout + [UUID?](repeating: nil, count: count)).prefix(count))
        let week = layout.map { id in id.flatMap { id in program.days.first { $0.id == id } } }
        let existing = week.compactMap { $0 }.filter { $0.kind == .run }.count
        let placements = placements(adding: runs - existing, to: week, restWeekdays: restWeekdays, directory: directory)
        guard !placements.isEmpty else { return program }
        var result = program
        result.weekLayout = layout
        var easyID = program.days.sorted { $0.order < $1.order }.first { $0.kind == .run && $0.runType == .easy }?.id
        for placement in placements {
            let dayID: UUID
            if placement.type == .easy, let easyID {
                dayID = easyID
            } else {
                let day = RunDayEditor.make(type: placement.type, order: result.days.count)
                result.days.append(day)
                dayID = day.id
                if placement.type == .easy { easyID = day.id }
            }
            result.weekLayout[placement.weekdayIndex] = dayID
        }
        for index in result.days.indices { result.days[index].order = index }
        result.sessionsPerWeek = result.weekLayout.compactMap { $0 }.count
        return result
    }
}

/// La semaine en cours de remplissage : ce que chaque jour porte, et ce qui pèse sur le lendemain.
private struct Draft {
    private enum Slot {
        case free
        case rest
        case run
        case strength(sets: Int)
    }

    private var slots: [Slot]
    /// Ce que coûte une course ce jour-là : 0 sans jambes lourdes la veille, 1 après une séance de jambes lourde, 2 après la
    /// plus lourde de la semaine.
    private let penalties: [Int]
    let hasLongRun: Bool

    init(week: [RoutineDay?], restWeekdays: [Weekday], directory: ExerciseDirectory) {
        let count = Weekday.allCases.count
        let days = Array((week + [RoutineDay?](repeating: nil, count: count)).prefix(count))
        let rest = Set(restWeekdays.map(\.index))
        slots = days.enumerated().map { index, day in
            guard let day else { return rest.contains(index) ? .rest : .free }
            return day.kind == .run ? .run : .strength(sets: day.exercises.reduce(0) { $0 + max(0, $1.sets) })
        }
        hasLongRun = days.contains { $0?.kind == .run && $0?.runType == .long }
        let legSets = days.map { day -> Int in
            guard let day, HeavyLegs.isHeavy(day, directory: directory) else { return 0 }
            return HeavyLegs.legSets(day, directory: directory)
        }
        let heaviest = legSets.max() ?? 0
        penalties = (0..<count).map { index in
            let before = legSets[(index + count - 1) % count]
            if before == 0 { return 0 }
            return before == heaviest ? 2 : 1
        }
    }

    var runIndices: [Int] {
        slots.indices.filter { if case .run = slots[$0] { true } else { false } }
    }

    private var freeIndices: [Int] {
        slots.indices.filter { if case .free = slots[$0] { true } else { false } }
    }

    mutating func markRun(at index: Int) {
        slots[index] = .run
    }

    /// Le dernier jour libre de la semaine qui ne suit pas des jambes lourdes ; `nil` s'il n'y en a pas.
    func longRunDay() -> Int? {
        freeIndices.last { penalties[$0] == 0 }
    }

    /// Le jour libre le moins exposé aux jambes lourdes, puis le plus loin des courses déjà posées, puis le plus tôt.
    func easyRunDay() -> Int? {
        let free = freeIndices
        guard let lowest = free.map({ penalties[$0] }).min() else { return nil }
        let runs = runIndices
        var best: Int?
        var bestDistance = -1
        for index in free where penalties[index] == lowest {
            let distance = runs.map { circularDistance($0, index) }.min() ?? Int.max
            if distance > bestDistance {
                best = index
                bestDistance = distance
            }
        }
        return best
    }

    /// Le jour de la séance de musculation qui compte le moins de séries ; à égalité, le plus tôt dans la semaine.
    func lightestStrengthDay() -> Int? {
        var best: Int?
        var bestSets = Int.max
        for index in slots.indices {
            guard case .strength(let sets) = slots[index], sets < bestSets else { continue }
            best = index
            bestSets = sets
        }
        return best
    }

    private func circularDistance(_ first: Int, _ second: Int) -> Int {
        let gap = abs(first - second)
        return min(gap, slots.count - gap)
    }
}
