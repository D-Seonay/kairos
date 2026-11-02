import Foundation
import PulseDomain

/// L'ajustement nommé d'un exercice : « <Nom> : +2,5 kg sur 2 séries, 12 répétitions atteintes la dernière fois ».
enum LoadAdjustmentText {
    static func adjustment(name: String, outcomes: [LoadProgression.Outcome], context: LoadProgression.Context) -> SessionAdjustment? {
        let increases = outcomes.compactMap { outcome -> (deltaKg: Double, reached: Int)? in
            if case .increased(let deltaKg, let reached) = outcome { return (deltaKg, reached) }
            return nil
        }
        if let first = increases.first {
            let isAssisted = context.loadKind == .assisted
            let delta = increases.map(\.deltaKg).max() ?? first.deltaKg
            let reason = reason(name: name, deltaKg: delta, sets: increases.count, reached: first.reached, context: context)
            return SessionAdjustment(kind: .load, reason: reason, value: isAssisted ? -delta : delta)
        }
        guard let atZero = outcomes.compactMap({ outcome -> Int? in
            if case .assistanceAtZero(let reached) = outcome { return reached }
            return nil
        }).first else { return nil }
        let reached = reachedText(atZero, context: context)
        let reason = String(localized: "\(name) : assistance à 0, \(reached) ; passe au poids du corps pour lester", bundle: .module)
        return SessionAdjustment(kind: .load, reason: reason, value: 0)
    }

    private static func reason(name: String, deltaKg: Double, sets: Int, reached: Int, context: LoadProgression.Context) -> String {
        let delta = kilograms(deltaKg)
        let change = context.loadKind == .assisted
            ? String(localized: "assistance −\(delta) kg", bundle: .module)
            : String(localized: "+\(delta) kg", bundle: .module)
        let setsText = sets == 1
            ? String(localized: "sur 1 série", bundle: .module)
            : String(localized: "sur \(sets) séries", bundle: .module)
        return String(localized: "\(name) : \(change) \(setsText), \(reachedText(reached, context: context))", bundle: .module)
    }

    private static func reachedText(_ reached: Int, context: LoadProgression.Context) -> String {
        context.tracksDuration
            ? String(localized: "\(reached) secondes atteintes la dernière fois", bundle: .module)
            : String(localized: "\(reached) répétitions atteintes la dernière fois", bundle: .module)
    }

    /// 2,5 ; 5 ; 1,25 : à la française, sans « ,0 ».
    private static func kilograms(_ value: Double) -> String {
        value.formatted(.number.locale(Locale(identifier: "fr_FR")).precision(.fractionLength(0...2)))
    }
}
