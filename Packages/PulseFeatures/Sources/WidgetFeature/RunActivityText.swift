import Foundation
import PulseDesignSystem
import PulseDomain

/// Les textes de la Live Activity de la course, sans ActivityKit : ils ne viennent que de la distance GPS filtrée, du temps et de
/// l'allure déjà présents dans l'état de l'activité. Jamais de fréquence cardiaque (frontière M8).
public enum RunActivityText {
    private static let dash = "—"

    public static var pausedTitle: String { String(localized: "En pause", bundle: .module) }
    public static var pauseTitle: String { String(localized: "Pause", bundle: .module) }
    public static var resumeTitle: String { String(localized: "Reprendre", bundle: .module) }

    public static var pauseLabel: String { String(localized: "Mettre la course en pause", bundle: .module) }
    public static var resumeLabel: String { String(localized: "Reprendre la course", bundle: .module) }

    /// « 4,38 km » ; « — » sans distance. Deux décimales fixes : la largeur ne saute pas d'une mise à jour à l'autre.
    public static func distance(_ meters: Double?) -> String {
        guard let meters, meters.isFinite else { return dash }
        let km = (meters / 1000).formatted(
            .number.locale(Locale(identifier: "fr_FR")).precision(.fractionLength(2)).grouping(.never))
        return String(localized: "\(km) km", bundle: .module)
    }

    /// « 5'32" /km » ; « — » sans allure.
    public static func pace(_ secondsPerKm: Int?) -> String {
        guard let secondsPerKm, secondsPerKm > 0 else { return dash }
        let minutes = secondsPerKm / 60
        let seconds = secondsPerKm % 60
        let padded = seconds < 10 ? "0\(seconds)" : "\(seconds)"
        return String(localized: "\(minutes)'\(padded)\" /km", bundle: .module)
    }

    /// « 12:34 », « 1:02:05 » : le temps en mouvement figé, affiché en pause. En marche, c'est le minuteur système qui l'affiche.
    public static func elapsed(seconds: Int) -> String {
        let total = max(0, seconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let rest = total % 60
        let pad: (Int) -> String = { $0 < 10 ? "0\($0)" : "\($0)" }
        return hours > 0 ? "\(hours):\(pad(minutes)):\(pad(rest))" : "\(minutes):\(pad(rest))"
    }

    /// « Course Sortie facile, en pause, 24 minutes 10, 4,4 kilomètres, 5 minutes 32 par kilomètre » : tout ce que l'activité montre,
    /// les unités en toutes lettres. Une valeur absente n'est pas dite.
    public static func spokenSummary(_ state: RunActivityState, elapsed: Int) -> String {
        var parts = [String(localized: "Course \(state.title)", bundle: .module)]
        if state.isPaused { parts.append(String(localized: "en pause", bundle: .module)) }
        parts.append(PulseSpoken.duration(seconds: elapsed))
        parts.append(contentsOf: spokenMetrics(state))
        return parts.joined(separator: ", ")
    }

    /// Ce que VoiceOver lit pour l'activité. En marche, le temps n'y est pas : le minuteur système le porte et reste juste entre deux
    /// mises à jour. En pause, le temps est figé, donc dit.
    public static func accessibilityLabel(_ state: RunActivityState) -> String {
        if state.isPaused { return spokenSummary(state, elapsed: state.frozenElapsedSeconds) }
        let parts = [String(localized: "Course \(state.title)", bundle: .module)] + spokenMetrics(state)
        return parts.joined(separator: ", ")
    }

    private static func spokenMetrics(_ state: RunActivityState) -> [String] {
        var parts: [String] = []
        if let meters = state.distanceMeters, meters.isFinite { parts.append(PulseSpoken.kilometres(meters / 1000)) }
        if let pace = state.averagePaceSecondsPerKm, pace > 0 { parts.append(PulseSpoken.pace(secondsPerKilometer: pace)) }
        return parts
    }
}
