import Foundation
import PulseDomain

/// Les photos de corps d'un jour de prise : au plus une par pose.
public struct BodyPhotoDay: Sendable, Equatable, Identifiable {
    /// Le début du jour local.
    public var day: Date
    public var photos: [BodyPose: BodyPhoto]

    public var id: Date { day }

    public init(day: Date, photos: [BodyPose: BodyPhoto]) {
        self.day = day
        self.photos = photos
    }
}

/// La frise des photos de corps : jours de prise, poses comparables, paire par défaut et variation de poids. Pure : les jours sont
/// des jours de calendrier (`startOfDay`), jamais des secondes.
public enum BodyPhotoTimeline {
    /// Un jour par date de prise, le plus récent d'abord ; si deux photos ont même pose et même jour, la plus récente gagne.
    public static func days(_ photos: [BodyPhoto], calendar: Calendar) -> [BodyPhotoDay] {
        let byDay = Dictionary(grouping: photos) { calendar.startOfDay(for: $0.takenAt) }
        return byDay.keys.sorted(by: >).map { day in
            let kept = Dictionary(grouping: byDay[day] ?? [], by: \.pose).compactMapValues { newest(of: $0) }
            return BodyPhotoDay(day: day, photos: kept)
        }
    }

    /// La photo de cette pose prise ce jour-là, la plus récente s'il y en a plusieurs.
    public static func existing(pose: BodyPose, on date: Date, in photos: [BodyPhoto], calendar: Calendar) -> BodyPhoto? {
        newest(of: photos.filter { $0.pose == pose && calendar.isDate($0.takenAt, inSameDayAs: date) })
    }

    /// Les poses qui ont au moins deux jours différents, dans l'ordre de `BodyPose.allCases`.
    public static func comparablePoses(_ photos: [BodyPhoto], calendar: Calendar) -> [BodyPose] {
        BodyPose.allCases.filter { pose in
            Set(photos.filter { $0.pose == pose }.map { calendar.startOfDay(for: $0.takenAt) }).count >= 2
        }
    }

    /// La plus ancienne et la plus récente photo de la pose ; nil sous deux jours.
    public static func defaultPair(pose: BodyPose, in photos: [BodyPhoto],
                                   calendar: Calendar) -> (before: BodyPhoto, after: BodyPhoto)? {
        let ofPose = days(photos.filter { $0.pose == pose }, calendar: calendar).compactMap { $0.photos[pose] }
        guard ofPose.count >= 2, let after = ofPose.first, let before = ofPose.last else { return nil }
        return (before, after)
    }

    /// Tendance de l'après moins tendance de l'avant. La tendance d'une date est celle du dernier jour mesuré dans les 7 jours qui
    /// finissent ce jour (`WeightTrend.window`) ; nil si l'une manque.
    public static func weightChange(trend: WeightTrend, from: Date, to: Date, calendar: Calendar) -> Double? {
        guard let before = trendValue(of: trend, on: from, calendar: calendar),
              let after = trendValue(of: trend, on: to, calendar: calendar) else { return nil }
        return after - before
    }

    private static func trendValue(of trend: WeightTrend, on date: Date, calendar: Calendar) -> Double? {
        let end = calendar.startOfDay(for: date)
        guard let start = calendar.date(byAdding: .day, value: 1 - WeightTrend.window, to: end) else { return nil }
        return trend.trendPoints.last { $0.date >= start && $0.date <= end }?.value
    }

    /// La photo ajoutée en dernier ; à égalité, la date de prise la plus tardive.
    private static func newest(of photos: [BodyPhoto]) -> BodyPhoto? {
        photos.max { lhs, rhs in
            lhs.createdAt != rhs.createdAt ? lhs.createdAt < rhs.createdAt : lhs.takenAt < rhs.takenAt
        }
    }
}
