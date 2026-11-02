import PulseDomain

/// Applique le tableau de la catégorie de récupération à un jour du programme (spec V1 §6.5, spec M3 §9.3).
/// Les exercices gardent leur ordre et leur identité : seuls `sets`, `targetRPE` et `restSeconds` changent.
public enum SessionAdjuster {
    public static let normalExtraRestSeconds = 15
    public static let fatigueExtraRestSeconds = 45
    public static let fatigueRPECap = 7.5
    public static let volumeReduction = 0.2
    public static let mobilityMinutes = 20

    public static func adjust(_ day: RoutineDay, category: RecoveryCategory) -> AdjustedSession {
        switch day.kind {
        case .strength: adjustStrength(day, category: category)
        case .run: adjustRun(day, category: category)
        }
    }

    private static func adjustStrength(_ day: RoutineDay, category: RecoveryCategory) -> AdjustedSession {
        switch category {
        case .optimal:
            return AdjustedSession(day: day)
        case .normal:
            var adjusted = day
            adjusted.exercises = day.exercises.map { addingRest(normalExtraRestSeconds, to: $0) }
            return AdjustedSession(day: adjusted, adjustments: [restAdjustment(normalExtraRestSeconds)])
        case .moderateFatigue:
            return moderateFatigue(day)
        case .overreached:
            let reason = String(localized: "Séance remplacée par \(mobilityMinutes) min de mobilité ou du repos, au choix",
                                bundle: .module)
            return AdjustedSession(day: day,
                                   adjustments: [SessionAdjustment(kind: .replaceWithMobility, reason: reason,
                                                                   value: Double(mobilityMinutes))])
        }
    }

    private static func moderateFatigue(_ day: RoutineDay) -> AdjustedSession {
        var adjustments: [SessionAdjustment] = []
        let before = day.exercises.reduce(0) { $0 + $1.sets }
        let reduced = VolumeReducer.reduce(day.exercises, by: volumeReduction)
        if reduced.removedSets > 0 {
            let after = before - reduced.removedSets
            let reason = String(localized: "Volume réduit de \(before) à \(after) séries", bundle: .module)
            adjustments.append(SessionAdjustment(kind: .volume, reason: reason, value: Double(-reduced.removedSets)))
        }
        var exercises = reduced.exercises
        if exercises.contains(where: { $0.targetRPE > fatigueRPECap }) {
            for index in exercises.indices { exercises[index].targetRPE = min(exercises[index].targetRPE, fatigueRPECap) }
            adjustments.append(SessionAdjustment(kind: .rpeCap, reason: String(localized: "Effort plafonné à RPE 7,5", bundle: .module),
                                                 value: fatigueRPECap))
        }
        exercises = exercises.map { addingRest(fatigueExtraRestSeconds, to: $0) }
        adjustments.append(restAdjustment(fatigueExtraRestSeconds))
        var adjusted = day
        adjusted.exercises = exercises
        return AdjustedSession(day: adjusted, adjustments: adjustments, removedSets: reduced.removedSets)
    }

    private static func adjustRun(_ day: RoutineDay, category: RecoveryCategory) -> AdjustedSession {
        switch category {
        case .moderateFatigue where day.runType == .intervals:
            let reason = String(localized: "Fractionné remplacé par une sortie facile", bundle: .module)
            return AdjustedSession(day: day, adjustments: [SessionAdjustment(kind: .swapIntervalsForEasy, reason: reason)])
        case .overreached:
            let reason = String(localized: "Repos conseillé plutôt que la course", bundle: .module)
            return AdjustedSession(day: day, adjustments: [SessionAdjustment(kind: .suggestRest, reason: reason)])
        default:
            return AdjustedSession(day: day)
        }
    }

    private static func addingRest(_ seconds: Int, to exercise: RoutineExercise) -> RoutineExercise {
        var copy = exercise
        copy.restSeconds += seconds
        return copy
    }

    private static func restAdjustment(_ seconds: Int) -> SessionAdjustment {
        SessionAdjustment(kind: .rest, reason: String(localized: "Repos rallongés de \(seconds) secondes", bundle: .module),
                          value: Double(seconds))
    }
}
