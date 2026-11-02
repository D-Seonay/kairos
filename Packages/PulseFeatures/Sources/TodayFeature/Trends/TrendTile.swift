import Foundation
import PulseDesignSystem
import PulseDomain
import PulseRecoveryEngine

/// Une tuile de tendance sur 14 jours : le titre, la valeur à retenir et la série pour la courbe (un trou par nuit sans mesure).
struct TrendTile: Equatable {
    static let days = 14
    private static let dash = "\u{2014}"

    var factor: Factor
    var title: String
    var valueText: String
    /// Du jour − 13 au jour, `nil` pour une nuit sans mesure.
    var values: [Double?]
    var accessibilityLabel: String

    /// Variabilité, FC repos et sommeil. La variabilité et la FC montrent leur dernière valeur, le sommeil sa moyenne.
    static func make(nights: [NightSample], day: Date, calendar: Calendar) -> [TrendTile] {
        let byDay = Dictionary(nights.map { (calendar.startOfDay(for: $0.day), $0) }, uniquingKeysWith: { _, latest in latest })
        let window = (0..<days).map { offset -> NightSample? in
            let date = calendar.date(byAdding: .day, value: offset + 1 - days, to: calendar.startOfDay(for: day))
            return date.flatMap { byDay[$0] }
        }
        let hrv = window.map { night in night?.sdnnMs.flatMap { HRVBaseline.isValid(sdnnMs: $0) ? $0 : nil } }
        let heartRate = window.map { night in night?.restingHeartRate.flatMap { $0.isFinite && $0 > 0 ? $0 : nil } }
        let sleep = window.map { night in night?.sleep.map { Double($0.asleepMinutes) } }
        return [
            last(.hrv, title: String(localized: "Variabilité, 14 jours", bundle: .module), values: hrv) {
                PulseFormat.integer($0, unit: "ms")
            },
            last(.restingHeartRate, title: String(localized: "FC repos, 14 jours", bundle: .module), values: heartRate) {
                PulseFormat.integer($0, unit: "bpm")
            },
            average(.sleep, title: String(localized: "Sommeil, 14 jours", bundle: .module), values: sleep)
        ]
    }

    private static func last(_ factor: Factor, title: String, values: [Double?], format: (Double) -> String) -> TrendTile {
        let text = values.compactMap { $0 }.last.map(format)
        let label = text.map { String(localized: "\(title), dernière valeur \($0)", bundle: .module) }
        return TrendTile(factor: factor, title: title, valueText: text ?? dash, values: values,
                         accessibilityLabel: label ?? noData(title))
    }

    private static func average(_ factor: Factor, title: String, values: [Double?]) -> TrendTile {
        let present = values.compactMap { $0 }
        let text = present.isEmpty ? nil : PulseFormat.duration(minutes: Int((present.reduce(0, +) / Double(present.count)).rounded()))
        let label = text.map { String(localized: "\(title), moyenne \($0)", bundle: .module) }
        return TrendTile(factor: factor, title: title, valueText: text ?? dash, values: values,
                         accessibilityLabel: label ?? noData(title))
    }

    private static func noData(_ title: String) -> String {
        String(localized: "\(title), aucune donnée", bundle: .module)
    }
}
