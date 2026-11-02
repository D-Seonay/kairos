import Foundation
import PulseDomain
import PulseRecoveryEngine

/// Les textes d'un exercice en séance : « précédent » par série, « Dernière fois… » et la ligne qui dit ce que le jour a changé.
/// `PulseFormat` (design system) n'est pas accessible d'ici : les durées et décimales sont formatées à la française sur place.
enum LiveSessionText {
    private static let french = Locale(identifier: "fr_FR")

    /// 2,5 ; 62,5 ; 60 : à la française, sans « ,0 ».
    static func decimal(_ value: Double) -> String {
        value.formatted(.number.locale(french).grouping(.never).precision(.fractionLength(0...2)))
    }

    /// 105 → « 1:45 ».
    static func clock(seconds: Int) -> String {
        let total = max(0, seconds)
        return "\(total / 60):\(total % 60 < 10 ? "0" : "")\(total % 60)"
    }

    /// La charge et la valeur (répétitions ou secondes) d'une série d'avant ; `nil` sans valeur.
    private struct Parts {
        var weight: String?
        var value: String
    }

    private static func parts(of set: WorkoutSet, loadKind: LoadKind, tracksDuration: Bool) -> Parts? {
        let weightKg = set.actualWeightKg ?? 0
        let weight: String? = switch loadKind {
        case .external: set.actualWeightKg.map(decimal)
        case .bodyweight: weightKg > 0 ? "+" + decimal(weightKg) : nil
        case .assisted: weightKg > 0 ? "−" + decimal(weightKg) : nil
        }
        if tracksDuration {
            guard let seconds = set.durationSeconds else { return nil }
            return Parts(weight: weight, value: String(localized: "\(seconds) s", bundle: .module))
        }
        guard let reps = set.actualReps else { return nil }
        return Parts(weight: weight, value: "\(reps)")
    }

    private static func joined(_ parts: Parts, weight: String?) -> String {
        guard let weight else { return parts.value }
        return String(localized: "\(weight) × \(parts.value)", bundle: .module)
    }

    /// « 70 × 5 » : la même série la dernière fois.
    static func previous(_ set: WorkoutSet?, loadKind: LoadKind, tracksDuration: Bool) -> String? {
        guard let set, let parts = parts(of: set, loadKind: loadKind, tracksDuration: tracksDuration) else { return nil }
        return joined(parts, weight: parts.weight)
    }

    /// « Dernière fois 60 × 12 · 70 × 5 · 5 » : une série qui garde la charge de la précédente n'affiche que sa valeur.
    static func lastTime(_ sets: [WorkoutSet], loadKind: LoadKind, tracksDuration: Bool) -> String? {
        var texts: [String] = []
        var previousWeight: String?
        for set in sets {
            guard let parts = parts(of: set, loadKind: loadKind, tracksDuration: tracksDuration) else { continue }
            if texts.isEmpty || parts.weight != previousWeight {
                texts.append(joined(parts, weight: parts.weight ?? (previousWeight == nil ? nil : "0")))
            } else {
                texts.append(parts.value)
            }
            previousWeight = parts.weight
        }
        guard !texts.isEmpty else { return nil }
        let list = texts.joined(separator: " · ")
        return String(localized: "Dernière fois \(list)", bundle: .module)
    }

    /// Les valeurs prévues d'une série en séance, pour la notification et la Live Activity : « 70 kg × 5 », « +10 kg × 8 »,
    /// « 8 rép. », « 30 s » ; `nil` sans valeur.
    static func planned(_ set: LiveSet, of exercise: LiveExercise) -> String? {
        let weightKg = set.weightKg ?? 0
        let weight: String? = switch exercise.loadKind {
        case .external: set.weightKg.map(decimal)
        case .bodyweight: weightKg > 0 ? "+" + decimal(weightKg) : nil
        case .assisted: weightKg > 0 ? "−" + decimal(weightKg) : nil
        }
        let load = weight.map { String(localized: "\($0) kg", bundle: .module) }
        let value: String? = exercise.tracksDuration
            ? set.durationSeconds.map { String(localized: "\($0) s", bundle: .module) }
            : set.reps.map { "\($0)" }
        switch (load, value) {
        case let (load?, value?): return String(localized: "\(load) × \(value)", bundle: .module)
        case let (load?, nil): return load
        case (nil, _) where exercise.tracksDuration: return value
        case (nil, _): return set.reps.map { String(localized: "\($0) rép.", bundle: .module) }
        }
    }

    /// Ce que le jour a changé pour un exercice, dans l'ordre : charge, séries, RPE, repos. `planned` : l'exercice avant les
    /// ajustements de la catégorie (`nil` pour un exercice ajouté en séance). `nil` si rien n'a changé.
    static func dayNote(loadAdjustment: SessionAdjustment?, hasHistory: Bool, policy: ProgressionPolicy,
                        planned: RoutineExercise?, adjusted: RoutineExercise) -> String? {
        var notes: [String] = []
        if !policy.allowsIncrease {
            if hasHistory { notes.append(String(localized: "Même charge", bundle: .module)) }
        } else if let reason = loadAdjustment?.reason {
            notes.append(reason)
        }
        if let planned {
            let removed = planned.sets - adjusted.sets
            if removed == 1 {
                notes.append(String(localized: "une série en moins", bundle: .module))
            } else if removed > 1 {
                notes.append(String(localized: "\(removed) séries en moins", bundle: .module))
            }
            if adjusted.targetRPE < planned.targetRPE {
                notes.append(String(localized: "RPE \(decimal(adjusted.targetRPE)) max", bundle: .module))
            }
            if adjusted.restSeconds != planned.restSeconds {
                notes.append(String(localized: "repos \(clock(seconds: adjusted.restSeconds))", bundle: .module))
            }
        }
        guard let first = notes.first else { return nil }
        notes[0] = first.prefix(1).uppercased() + first.dropFirst()
        return notes.joined(separator: ", ")
    }
}

public extension LiveExercise {
    /// Les valeurs prévues d'une de ses séries : « 70 kg × 5 », « +10 kg × 8 », « 8 rép. », « 30 s » ; `nil` sans valeur. La même
    /// phrase pour la notification de fin de repos et la ligne « série suivante » du bandeau de l'écran.
    func plannedText(for set: LiveSet) -> String? {
        LiveSessionText.planned(set, of: self)
    }
}
