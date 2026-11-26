import Foundation
import PulseContent
import PulseDomain

/// L'objectif d'un jour de course : aucun, une durée ou une distance, jamais les deux (comme `RunTarget`).
public enum RunGoal: Sendable, Equatable {
    case none
    case minutes(Int)
    case kilometres(Double)
}

/// La forme d'un objectif de course, sans sa valeur : ce que l'éditeur fait choisir d'abord.
public enum RunGoalKind: Sendable, Equatable, CaseIterable {
    case none
    case duration
    case distance
}

extension RunGoal {
    public var kind: RunGoalKind {
        switch self {
        case .none: .none
        case .minutes: .duration
        case .kilometres: .distance
        }
    }
}

/// Les bornes que l'éditeur impose à l'objectif d'un jour de course, et ses valeurs de départ.
public enum RunDayRules {
    public static let minutes = 10...240
    public static let minutesStep = 5
    public static let kilometres = 1.0...60.0
    public static let kilometresStep = 1.0
    /// Le type d'une course ajoutée d'un seul geste.
    public static let defaultType = RunType.easy
    /// La durée et la distance proposées quand on passe d'un objectif à l'autre.
    public static let defaultMinutes = 30
    public static let defaultKilometres = 5.0

    /// 30 min pour une sortie facile ou un fractionné, 1 h pour une sortie longue.
    public static func defaultGoal(for type: RunType) -> RunGoal {
        switch type {
        case .easy, .intervals: .minutes(defaultMinutes)
        case .long: .minutes(60)
        }
    }

    /// L'objectif ramené dans ses bornes.
    public static func clamped(_ goal: RunGoal) -> RunGoal {
        switch goal {
        case .none: .none
        case .minutes(let value): .minutes(min(max(value, minutes.lowerBound), minutes.upperBound))
        case .kilometres(let value): .kilometres(min(max(value, kilometres.lowerBound), kilometres.upperBound))
        }
    }
}

/// Crée et modifie un jour de course sans l'enregistrer : chaque fonction rend une copie du jour.
public enum RunDayEditor {
    /// Un jour de course prêt à courir : nommé d'après son type, avec l'objectif donné ou celui de son type.
    public static func make(type: RunType = RunDayRules.defaultType, goal: RunGoal? = nil, order: Int) -> RoutineDay {
        let day = RoutineDay(order: order, name: type.localizedName, kind: .run, runType: type)
        return setGoal(goal ?? RunDayRules.defaultGoal(for: type), in: day)
    }

    /// L'objectif enregistré ; si un jour porte une durée et une distance, la durée l'emporte, comme à l'affichage.
    public static func goal(of day: RoutineDay) -> RunGoal {
        if let minutes = day.runTargetMinutes { return .minutes(minutes) }
        if let kilometres = day.runTargetKm { return .kilometres(kilometres) }
        return .none
    }

    /// Change le type. Le jour prend le nom du nouveau type : une course n'a pas d'autre nom à l'écran. L'objectif reste.
    public static func setType(_ type: RunType, in day: RoutineDay) -> RoutineDay {
        guard day.runType != type else { return day }
        var result = day
        result.runType = type
        result.name = type.localizedName
        return result
    }

    /// Fixe l'objectif, ramené dans les bornes de `RunDayRules` : une durée efface la distance, et inversement.
    public static func setGoal(_ goal: RunGoal, in day: RoutineDay) -> RoutineDay {
        var result = day
        result.runTargetMinutes = nil
        result.runTargetKm = nil
        switch RunDayRules.clamped(goal) {
        case .none: break
        case .minutes(let minutes): result.runTargetMinutes = minutes
        case .kilometres(let kilometres): result.runTargetKm = kilometres
        }
        return result
    }

    /// Le jour de course remis d'aplomb : un type, un seul objectif dans ses bornes, aucun exercice.
    static func normalized(_ day: RoutineDay) -> RoutineDay {
        var result = setGoal(goal(of: day), in: day)
        result.runType = day.runType ?? RunDayRules.defaultType
        result.exercises = []
        return result
    }
}
