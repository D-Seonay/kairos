import Foundation
import PulseDesignSystem

extension RunRecapModel {
    /// La carte de partage de la course : distance, temps en mouvement, allure, dénivelé ou FC, et le tracé s'il y en a un.
    public func shareContent(calendar: Calendar) -> ShareCardContent {
        Self.shareContent(title: title, date: data.session.startedAt, movingSeconds: movingSeconds, distanceMeters: distanceMeters,
                          averagePace: averagePace, elevationGain: elevationGain, averageHeartRate: averageHeartRate,
                          latitudes: points.map(\.latitude), longitudes: points.map(\.longitude), calendar: calendar)
    }

    // swiftlint:disable:next function_parameter_count
    nonisolated static func shareContent(title: String, date: Date, movingSeconds: Int, distanceMeters: Double?,
                                         averagePace: Int?, elevationGain: Double?, averageHeartRate: Double?,
                                         latitudes: [Double], longitudes: [Double], calendar: Calendar) -> ShareCardContent {
        var metrics: [ShareCardMetric] = []
        if distanceMeters != nil {
            metrics.append(ShareCardMetric(value: RunText.distance(distanceMeters), label: String(localized: "Distance", bundle: .module),
                                           caption: RunText.distance(distanceMeters)))
        }
        metrics.append(ShareCardMetric(value: RunText.elapsed(seconds: movingSeconds),
                                       label: String(localized: "En mouvement", bundle: .module),
                                       caption: RunText.elapsed(seconds: movingSeconds)))
        if averagePace != nil {
            metrics.append(ShareCardMetric(value: RunText.pace(averagePace), label: String(localized: "Allure", bundle: .module),
                                           caption: RunText.pace(averagePace)))
        }
        if let gain = elevationGain {
            metrics.append(ShareCardMetric(value: RunText.elevation(gain), label: String(localized: "Dénivelé", bundle: .module),
                                           caption: RunText.elevation(gain)))
        } else if let bpm = averageHeartRate {
            metrics.append(ShareCardMetric(value: RunText.heartRate(bpm), label: String(localized: "FC moyenne", bundle: .module),
                                           caption: RunText.heartRate(bpm)))
        }
        let route = ShareRoute.normalized(latitudes: latitudes, longitudes: longitudes)
        let day = "\(PulseSpoken.weekday(date, calendar: calendar)) \(PulseSpoken.date(date, calendar: calendar))"
        return ShareCardContent(
            eyebrow: String(localized: "Course", bundle: .module),
            title: title.isEmpty ? String(localized: "Course", bundle: .module) : title,
            subtitle: day, metrics: metrics, visual: route.isEmpty ? .none : .route(route))
    }
}
