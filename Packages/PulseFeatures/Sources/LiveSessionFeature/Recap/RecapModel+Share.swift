import Foundation
import PulseDesignSystem
import PulseServices

extension RecapModel {
    /// La carte de partage du bilan : durée, tonnage (s'il y en a), séries et records, la carte musculaire et un record par
    /// exercice ; `nil` tant que le bilan n'est pas lu.
    public func shareContent(calendar: Calendar) -> ShareCardContent? {
        recap.map { Self.shareContent(of: $0, calendar: calendar) }
    }

    nonisolated static func shareContent(of recap: SessionRecap, calendar: Calendar) -> ShareCardContent {
        var metrics = [ShareCardMetric(value: PulseFormat.duration(minutes: recap.durationMinutes),
                                       label: String(localized: "Durée", bundle: .module),
                                       caption: PulseFormat.duration(minutes: recap.durationMinutes))]
        if recap.tonnageKg > 0 {
            let tonnage = PulseFormat.grouped(recap.tonnageKg, maxFractionDigits: 1)
            metrics.append(ShareCardMetric(value: tonnage, label: String(localized: "kg soulevés", bundle: .module),
                                           caption: String(localized: "\(tonnage) kg", bundle: .module)))
        }
        metrics.append(ShareCardMetric(value: "\(recap.workingSets)", label: String(localized: "Séries", bundle: .module),
                                       caption: RecapView.setsText(recap.workingSets)))
        let count = recap.beatenRecords.count
        if count > 0 {
            metrics.append(ShareCardMetric(value: "\(count)", label: RecapView.recordsTitle(count),
                                           caption: Self.recordsCaption(count)))
        }
        let levels = MuscleIntensity.levels(weights: recap.muscleWeights)
        return ShareCardContent(
            eyebrow: String(localized: "Séance", bundle: .module),
            title: recap.title.isEmpty ? String(localized: "Séance", bundle: .module) : recap.title,
            subtitle: RecapView.subtitle(title: "", endedAt: recap.endedAt, calendar: calendar),
            metrics: metrics, highlights: recordHeadlines(recap.beatenRecords), visual: levels.isEmpty ? .none : .muscles(levels))
    }

    /// Un record par exercice, le premier battu, sans « nouveau record » : le trophée le dit.
    nonisolated static func recordHeadlines(_ records: [BeatenRecord]) -> [String] {
        var seen = Set<String>()
        return records.compactMap { record in seen.insert(record.exerciseName).inserted ? record.headline : nil }
    }

    /// « 1 record », « 3 records ».
    nonisolated static func recordsCaption(_ count: Int) -> String {
        count == 1 ? String(localized: "1 record", bundle: .module) : String(localized: "\(count) records", bundle: .module)
    }
}
