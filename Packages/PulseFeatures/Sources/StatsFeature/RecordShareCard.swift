import Foundation
import PulseDesignSystem
import PulseDomain
import PulseServices

/// Les cartes de partage d'un record (Stats → Records et le mur du profil) : la valeur en très grand, la série d'origine ou
/// l'allure, et le gain sur le record d'avant quand il y en a un.
public enum RecordShareCard {
    /// Un record de force : « 96 kg » (1RM estimé) ou « 14 reps », avec la série « 85 × 5 » et « +2,5 kg ».
    public static func strength(_ line: StrengthRecordLine, calendar: Calendar) -> ShareCardContent {
        let isReps = line.kind == .repsAtWeight
        let value = isReps
            ? String(localized: "\(Int(line.value.rounded())) reps", bundle: .module)
            : String(localized: "\(PulseFormat.decimal(line.value, maxFractionDigits: 1)) kg", bundle: .module)
        let label = switch line.kind {
        case .repsAtWeight: String(localized: "Répétitions", bundle: .module)
        case .maxWeight: String(localized: "Charge maximale", bundle: .module)
        case .estimatedOneRepMax: String(localized: "1RM estimé", bundle: .module)
        }
        var metrics: [ShareCardMetric] = []
        if let weight = line.weightKg, weight > 0, let reps = line.reps {
            let load = PulseFormat.decimal(weight, maxFractionDigits: 2)
            metrics.append(ShareCardMetric(value: "\(load) × \(reps)", label: String(localized: "Série", bundle: .module),
                                           caption: String(localized: "\(load) kg × \(reps)", bundle: .module)))
        }
        if let gain = line.gain, gain > 0 {
            let text = isReps
                ? String(localized: "+\(Int(gain.rounded())) reps", bundle: .module)
                : String(localized: "+\(PulseFormat.decimal(gain, maxFractionDigits: 1)) kg", bundle: .module)
            metrics.append(ShareCardMetric(value: text, label: String(localized: "Progression", bundle: .module), caption: text))
        }
        return ShareCardContent(
            eyebrow: String(localized: "Record", bundle: .module), title: line.name, subtitle: day(line.date, calendar: calendar),
            metrics: metrics, visual: .hero(value: value, label: label))
    }

    /// Un meilleur temps de course : « 24:13 » sur 5 km, avec l'allure moyenne ; `nil` pour une distance jamais couverte.
    public static func run(_ best: RunBest, calendar: Calendar) -> ShareCardContent? {
        guard let seconds = best.seconds, seconds > 0, seconds.isFinite else { return nil }
        let paceSeconds = Int((seconds / (best.distance.rawValue / 1_000)).rounded())
        let rest = paceSeconds % 60
        let pace = "\(paceSeconds / 60)'\(rest < 10 ? "0" : "")\(rest)\"/km"
        return ShareCardContent(
            eyebrow: String(localized: "Record", bundle: .module), title: title(best.distance),
            subtitle: best.date.map { day($0, calendar: calendar) } ?? "",
            metrics: [ShareCardMetric(value: pace, label: String(localized: "Allure", bundle: .module), caption: pace)],
            visual: .hero(value: StatsText.raceTime(seconds: seconds), label: String(localized: "Meilleur temps", bundle: .module)))
    }

    /// « 5 km », « 10 km », « Semi-marathon ».
    static func title(_ distance: RunDistance) -> String {
        switch distance {
        case .fiveK: String(localized: "5 km", bundle: .module)
        case .tenK: String(localized: "10 km", bundle: .module)
        case .half: String(localized: "Semi-marathon", bundle: .module)
        }
    }

    /// « mardi 24 novembre ».
    static func day(_ date: Date, calendar: Calendar) -> String {
        let style = Date.FormatStyle(locale: Locale(identifier: "fr_FR"), calendar: calendar, timeZone: calendar.timeZone)
            .weekday(.wide).day().month(.wide)
        return date.formatted(style)
    }
}
