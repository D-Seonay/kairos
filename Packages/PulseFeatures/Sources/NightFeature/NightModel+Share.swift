import Foundation
import PulseDesignSystem
import PulseDomain

extension NightModel {
    /// La carte de partage de la nuit affichée ; `nil` sans nuit.
    var shareContent: ShareCardContent? {
        current.map { Self.shareContent(of: $0.night, calendar: calendar) }
    }

    /// Avec des phases : l'hypnogramme, le temps endormi et les minutes de profond, paradoxal et léger. Sans phases : le temps
    /// endormi en très grand et les réveils.
    nonisolated static func shareContent(of night: NightSleep, calendar: Calendar) -> ShareCardContent {
        let asleep = PulseFormat.duration(minutes: night.asleepMinutes)
        let title = NightText.title(night, calendar: calendar)
        let subtitle = NightText.times(night, calendar: calendar)
        let eyebrow = String(localized: "Nuit", bundle: .module)
        guard night.hasStages else {
            let awakenings = NightText.awakenings(night.awakenings)
            return ShareCardContent(
                eyebrow: eyebrow, title: title, subtitle: subtitle,
                metrics: [ShareCardMetric(value: "\(night.awakenings)", label: String(localized: "Réveils", bundle: .module),
                                          caption: awakenings)],
                visual: .hero(value: asleep, label: String(localized: "Temps endormi", bundle: .module)))
        }
        func metric(_ minutes: Int, _ stage: SleepStage) -> ShareCardMetric {
            let text = PulseFormat.duration(minutes: minutes)
            return ShareCardMetric(value: text, label: stage.displayName, caption: "\(stage.displayName.lowercased()) \(text)")
        }
        let rows = SleepStage.chartOrder
        let bars = ShareCardHypnogram.bars(
            of: night.segments.map { ShareCardHypnogram.Segment(row: rows.firstIndex(of: $0.stage), start: $0.start, end: $0.end) },
            from: night.fellAsleep, to: night.wokeUp, rowCount: rows.count)
        return ShareCardContent(
            eyebrow: eyebrow, title: title, subtitle: subtitle,
            metrics: [ShareCardMetric(value: asleep, label: String(localized: "Endormi", bundle: .module), caption: asleep),
                      metric(night.deepMinutes, .deep), metric(night.remMinutes, .rem), metric(night.coreMinutes, .core)],
            visual: .hypnogram(ShareCardHypnogram(rows: rows.map(\.displayName), bars: bars)))
    }
}
