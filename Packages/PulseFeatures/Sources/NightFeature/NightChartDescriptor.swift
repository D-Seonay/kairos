import Foundation
import PulseDesignSystem
import PulseDomain

/// Ce que VoiceOver lit de l'hypnogramme : une série par phase présente, un point par segment (son début et sa durée).
enum NightChartDescriptor {
    /// L'ordre des séries : les phases endormies de la plus profonde à la plus légère, puis l'éveil.
    private static let order: [SleepStage] = [.deep, .core, .rem, .asleepUnspecified, .awake]

    /// Seules les phases qui ont leur rangée dans l'hypnogramme : quelques secondes sans phase ne font pas de série.
    static func series(_ night: NightSleep) -> [PulseChartDescriptor.Series] {
        let rows = NightText.hypnogramRows(night)
        return order.filter(rows.contains).compactMap { stage in
            let points = night.segments.filter { $0.stage == stage }.map { segment in
                PulseChartDescriptor.Point(date: segment.start, y: (segment.end.timeIntervalSince(segment.start) / 60).rounded())
            }
            return points.isEmpty ? nil
                : PulseChartDescriptor.Series(name: NightText.stageName(stage, hasStages: night.hasStages), points: points)
        }
    }

    static func hypnogram(_ night: NightSleep, calendar: Calendar) -> PulseChartDescriptor {
        let longest = night.segments.map { $0.end.timeIntervalSince($0.start) / 60 }.max() ?? 0
        return PulseChartDescriptor(
            title: String(localized: "Phases de la nuit", bundle: .module),
            summary: NightText.spokenSummary(night, calendar: calendar),
            xAxis: .dates(title: String(localized: "Début de la phase", bundle: .module)),
            yAxis: .init(title: String(localized: "Durée de la phase", bundle: .module), unit: "",
                         range: 0...max(longest, 1), valueText: { NightText.spokenMinutes(Int($0.rounded())) }),
            series: series(night),
            calendar: calendar)
    }
}
