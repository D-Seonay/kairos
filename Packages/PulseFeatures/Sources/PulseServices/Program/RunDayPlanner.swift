import Foundation
import PulseDomain

/// Place dans la semaine type les sorties que l'onboarding propose (« 2 séances de musculation et 1 sortie »), pour que le
/// programme adopté les contienne vraiment. Tout est pur : la même semaine et la même demande donnent le même résultat.
/// Une sortie ne prend jamais la place d'une séance de musculation : sans jour libre, elle n'est pas posée.
public enum RunDayPlanner {
    /// Une sortie à poser : son jour (0 = lundi) et son type.
    public struct Placement: Sendable, Equatable {
        public var weekdayIndex: Int
        public var type: RunType

        public init(weekdayIndex: Int, type: RunType) {
            self.weekdayIndex = weekdayIndex
            self.type = type
        }
    }

    /// Les sorties que le curseur demande : les jours que la musculation, `round(jours × (1 − focus))`, ne prend pas.
    public static func requestedRuns(focus: Double, daysPerWeek: Int) -> Int {
        let days = max(0, daysPerWeek)
        let strength = min(days, max(0, Int((Double(days) * (1 - focus)).rounded())))
        return days - strength
    }

    /// Où poser jusqu'à `count` sorties de plus dans `week` (lundi à dimanche, `nil` pour un repos).
    ///
    /// - Seulement sur un jour libre qui n'est pas un repos obligatoire. Quand il y a moins de jours libres que de sorties,
    ///   les sorties en trop ne sont pas posées : aucune séance ne cède sa place.
    /// - Parmi les jours libres, d'abord ceux qui ne suivent pas une séance de jambes lourde (`HeavyLegs`, comme la règle
    ///   anti-interférence) ; à défaut ceux qui suivent une séance de jambes moins chargée ; le lendemain de la plus lourde
    ///   seulement s'il ne reste que lui. La semaine se répète : lundi suit dimanche.
    /// - Avec deux sorties ou plus dans la semaine, une seule est longue, le plus tard possible dans la semaine, et seulement
    ///   un jour qui ne suit pas des jambes lourdes : la règle anti-interférence la déplacerait sinon chaque semaine. Les
    ///   autres sont faciles, le plus loin possible des courses déjà là. Une sortie seule est facile.
    public static func placements(adding count: Int, to week: [RoutineDay?], restWeekdays: [Weekday],
                                  directory: ExerciseDirectory) -> [Placement] {
        var draft = Draft(week: week, restWeekdays: restWeekdays, directory: directory)
        let placeable = min(count, draft.freeCount)
        guard placeable > 0 else { return [] }
        var placements: [Placement] = []
        if draft.runCount + placeable >= 2, !draft.hasLongRun, let index = draft.longRunDay() {
            draft.markRun(at: index)
            placements.append(Placement(weekdayIndex: index, type: .long))
        }
        while placements.count < placeable, let index = draft.easyRunDay() {
            draft.markRun(at: index)
            placements.append(Placement(weekdayIndex: index, type: .easy))
        }
        return placements
    }

    /// Le programme avec les sorties qui lui manquent pour en compter `runs`, tant que sa semaine ne dépasse pas `sessions`
    /// séances : il en reçoit `min(runs − celles qu'il a déjà, sessions − ses séances)`, jamais moins de zéro. Les sorties du
    /// programme comptent et ne sont jamais retirées ; un programme qui dépasse déjà `sessions` reste tel quel.
    /// Les sorties faciles ajoutées partagent un même jour de course (celui du programme s'il en a un), comme une routine
    /// placée deux fois dans la semaine.
    public static func adding(runs: Int, upTo sessions: Int, to program: Program, restWeekdays: [Weekday],
                              directory: ExerciseDirectory) -> Program {
        let count = Weekday.allCases.count
        let layout = Array((program.weekLayout + [UUID?](repeating: nil, count: count)).prefix(count))
        let week = layout.map { id in id.flatMap { id in program.days.first { $0.id == id } } }
        let placed = week.compactMap { $0 }
        let missing = min(runs - placed.filter { $0.kind == .run }.count, sessions - placed.count)
        let placements = placements(adding: missing, to: week, restWeekdays: restWeekdays, directory: directory)
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
        /// Un repos obligatoire ou une séance de musculation : rien ne s'y pose.
        case taken
        case run
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
            guard let day else { return rest.contains(index) ? .taken : .free }
            return day.kind == .run ? .run : .taken
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

    private var runIndices: [Int] {
        slots.indices.filter { if case .run = slots[$0] { true } else { false } }
    }

    private var freeIndices: [Int] {
        slots.indices.filter { if case .free = slots[$0] { true } else { false } }
    }

    var runCount: Int {
        runIndices.count
    }

    var freeCount: Int {
        freeIndices.count
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

    private func circularDistance(_ first: Int, _ second: Int) -> Int {
        let gap = abs(first - second)
        return min(gap, slots.count - gap)
    }
}
