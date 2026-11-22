import Foundation
import PulseContent
import PulseDesignSystem
import PulseServices

extension SessionSummary {
    /// « 19 séries · ~ 55 min · RPE max 8 » : la ligne visible de la carte de séance, « 1 série » au singulier.
    var statsText: String {
        let sets = PulseSpoken.count(setCount, singular: String(localized: "série", bundle: .module),
                                     plural: String(localized: "séries", bundle: .module))
        let duration = String(localized: "~ \(PulseFormat.duration(minutes: estimatedMinutes))", bundle: .module)
        let rpe = PulseFormat.decimal(maxRPE, maxFractionDigits: 1)
        return [sets, duration, String(localized: "RPE max \(rpe)", bundle: .module)].joined(separator: " · ")
    }

    /// « 19 séries, environ 55 minutes, effort perçu maximal 8 sur 10, muscles principaux : pectoraux, triceps, épaules » :
    /// ce que VoiceOver lit de la séance du jour, d'un seul tenant. Ce qu'on ne sait pas (effort, muscles) se tait.
    var spokenText: String {
        var parts = [
            PulseSpoken.count(setCount, singular: String(localized: "série", bundle: .module),
                              plural: String(localized: "séries", bundle: .module)),
            String(localized: "environ \(PulseSpoken.duration(seconds: estimatedMinutes * 60))", bundle: .module)
        ]
        if maxRPE > 0 {
            let rpe = PulseFormat.decimal(maxRPE, maxFractionDigits: 1)
            parts.append(String(localized: "effort perçu maximal \(rpe) sur 10", bundle: .module))
        }
        if !topMuscles.isEmpty {
            let names = topMuscles.map { $0.localizedName.lowercased() }.joined(separator: ", ")
            parts.append(String(localized: "muscles principaux : \(names)", bundle: .module))
        }
        return parts.joined(separator: ", ")
    }
}
