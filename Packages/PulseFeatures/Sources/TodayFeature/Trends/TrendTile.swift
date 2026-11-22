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
        let latest = values.compactMap { $0 }.last
        let spokenTitle = spokenTitle(factor)
        let label = latest.map { value -> String in
            let spoken = String(localized: "\(spokenTitle), dernière valeur \(spokenValue(factor, value))", bundle: .module)
            return withDirection(spoken, values: values)
        }
        return TrendTile(factor: factor, title: title, valueText: latest.map(format) ?? dash, values: values,
                         accessibilityLabel: label ?? noData(spokenTitle))
    }

    private static func average(_ factor: Factor, title: String, values: [Double?]) -> TrendTile {
        let present = values.compactMap { $0 }
        let mean = present.isEmpty ? nil : (present.reduce(0, +) / Double(present.count)).rounded()
        let spokenTitle = spokenTitle(factor)
        let label = mean.map { value -> String in
            let spoken = String(localized: "\(spokenTitle), moyenne \(spokenValue(factor, value))", bundle: .module)
            return withDirection(spoken, values: values)
        }
        return TrendTile(factor: factor, title: title, valueText: mean.map { PulseFormat.duration(minutes: Int($0)) } ?? dash,
                         values: values, accessibilityLabel: label ?? noData(spokenTitle))
    }

    private static func noData(_ title: String) -> String {
        String(localized: "\(title), aucune donnée", bundle: .module)
    }

    // MARK: - Parlé

    /// Le titre tel que VoiceOver le dit : « Fréquence cardiaque au repos, 14 jours » (le titre affiché abrège en « FC repos »).
    static func spokenTitle(_ factor: Factor) -> String {
        switch factor {
        case .hrv: String(localized: "Variabilité, 14 jours", bundle: .module)
        case .restingHeartRate: String(localized: "Fréquence cardiaque au repos, 14 jours", bundle: .module)
        case .sleep: String(localized: "Sommeil, 14 jours", bundle: .module)
        }
    }

    /// « 44 millisecondes », « 54 battements par minute », « 7 heures 12 » (le sommeil se donne en minutes).
    static func spokenValue(_ factor: Factor, _ value: Double) -> String {
        guard value.isFinite, abs(value) < 1e9 else { return "" }
        let rounded = Int(value.rounded())
        switch factor {
        case .hrv:
            return PulseSpoken.count(rounded, singular: String(localized: "milliseconde", bundle: .module),
                                     plural: String(localized: "millisecondes", bundle: .module))
        case .restingHeartRate:
            let beats = PulseSpoken.count(rounded, singular: String(localized: "battement", bundle: .module),
                                          plural: String(localized: "battements", bundle: .module))
            return String(localized: "\(beats) par minute", bundle: .module)
        case .sleep:
            return PulseSpoken.duration(seconds: rounded * 60)
        }
    }

    /// Le sens de la tendance : la dernière semaine contre celle d'avant.
    enum Direction: Equatable {
        case up, down, steady

        var spoken: String {
            switch self {
            case .up: String(localized: "tendance en hausse", bundle: .module)
            case .down: String(localized: "tendance en baisse", bundle: .module)
            case .steady: String(localized: "tendance stable", bundle: .module)
            }
        }
    }

    /// Le sens de la tendance : la moyenne de la dernière semaine contre celle de la semaine d'avant, « stable » sous 5 % d'écart.
    /// `nil` sans deux mesures de chaque côté (ou sans moyenne de référence) : une tendance ne se devine pas.
    static func direction(of values: [Double?]) -> Direction? {
        guard values.count >= days else { return nil }
        let window = Array(values.suffix(days))
        let half = days / 2
        let older = window.prefix(half).compactMap { $0 }
        let recent = window.suffix(half).compactMap { $0 }
        guard older.count >= minimumMeasures, recent.count >= minimumMeasures else { return nil }
        let before = older.reduce(0, +) / Double(older.count)
        let after = recent.reduce(0, +) / Double(recent.count)
        guard before > 0 else { return nil }
        let change = (after - before) / before
        if change > steadyShare { return .up }
        if change < -steadyShare { return .down }
        return .steady
    }

    private static let steadyShare = 0.05
    private static let minimumMeasures = 2

    private static func withDirection(_ text: String, values: [Double?]) -> String {
        guard let direction = direction(of: values) else { return text }
        return String(localized: "\(text), \(direction.spoken)", bundle: .module)
    }
}
