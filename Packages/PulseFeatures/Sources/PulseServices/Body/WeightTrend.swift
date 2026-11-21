import Foundation
import PulseDomain

/// Le poids d'un jour : la mesure retenue (spec M7 §14).
public struct WeightDay: Sendable, Equatable, Identifiable {
    public var date: Date
    public var weightKg: Double
    public var source: MeasurementSource

    public var id: Date { date }

    public init(date: Date, weightKg: Double, source: MeasurementSource) {
        self.date = date
        self.weightKg = weightKg
        self.source = source
    }
}

/// La dernière masse grasse lue.
public struct BodyFatReading: Sendable, Equatable {
    public var percent: Double
    public var date: Date

    public init(percent: Double, date: Date) {
        self.percent = percent
        self.date = date
    }
}

/// La tendance du poids : une valeur par jour mesuré, puis la moyenne des jours mesurés des 7 derniers jours. Pure : les jours
/// sont des jours de calendrier (`startOfDay`, `date(byAdding: .day)`), jamais des secondes.
public struct WeightTrend: Sendable, Equatable {
    /// Les jours de la moyenne.
    public static let window = 7
    /// Sans pesée depuis autant de jours, la tendance s'affiche avec sa date.
    public static let staleDays = 14

    /// Une valeur par jour mesuré, chronologique.
    public var days: [WeightDay]
    /// Pour chaque jour mesuré, la moyenne des jours mesurés des 7 jours finissant ce jour (la date est le début du jour).
    public var trendPoints: [StatsPoint]
    /// Le dernier point de tendance.
    public var current: Double?
    /// Le début du dernier jour mesuré.
    public var lastMeasured: Date?
    /// Aucune pesée depuis 14 jours.
    public var isStale: Bool
    /// `current` moins la tendance du dernier jour mesuré au plus tard 30 jours avant `lastMeasured` ; nul sans un tel jour.
    public var change30Days: Double?
    public var latestBodyFat: BodyFatReading?

    public static func make(measurements: [BodyMeasurement], now: Date, calendar: Calendar) -> WeightTrend {
        let days = weightDays(of: measurements, calendar: calendar)
        let points = days.map { day in
            let first = calendar.date(byAdding: .day, value: 1 - window, to: day.date) ?? day.date
            let inWindow = days.filter { $0.date >= first && $0.date <= day.date }
            return StatsPoint(date: day.date, value: inWindow.map(\.weightKg).reduce(0, +) / Double(inWindow.count))
        }
        let lastMeasured = days.last?.date
        let today = calendar.startOfDay(for: now)
        let staleLimit = calendar.date(byAdding: .day, value: -staleDays, to: today) ?? today
        let fat = measurements.filter { $0.bodyFatPercent != nil }.max { lhs, rhs in
            lhs.date != rhs.date ? lhs.date < rhs.date : lhs.createdAt < rhs.createdAt
        }
        return WeightTrend(
            days: days, trendPoints: points, current: points.last?.value, lastMeasured: lastMeasured,
            isStale: lastMeasured.map { $0 < staleLimit } ?? false,
            change30Days: change(points: points, lastMeasured: lastMeasured, calendar: calendar),
            latestBodyFat: fat.flatMap { measurement in
                measurement.bodyFatPercent.map { BodyFatReading(percent: $0, date: measurement.date) }
            })
    }

    /// Une valeur par jour : la dernière mesure de poids du jour par `date`, une mesure manuelle l'emportant sur Apple Santé.
    private static func weightDays(of measurements: [BodyMeasurement], calendar: Calendar) -> [WeightDay] {
        let weighed = measurements.filter { $0.weightKg != nil }
        let byDay = Dictionary(grouping: weighed) { calendar.startOfDay(for: $0.date) }
        return byDay.keys.sorted().compactMap { day in
            let candidates = byDay[day] ?? []
            let manual = candidates.filter { $0.source == .manual }
            let pool = manual.isEmpty ? candidates : manual
            let chosen = pool.max { lhs, rhs in
                lhs.date != rhs.date ? lhs.date < rhs.date : lhs.createdAt < rhs.createdAt
            }
            return chosen?.weightKg.map { WeightDay(date: day, weightKg: $0, source: chosen?.source ?? .manual) }
        }
    }

    private static func change(points: [StatsPoint], lastMeasured: Date?, calendar: Calendar) -> Double? {
        guard let last = points.last, let lastMeasured,
              let limit = calendar.date(byAdding: .day, value: -30, to: lastMeasured),
              let reference = points.last(where: { $0.date <= limit }) else { return nil }
        return last.value - reference.value
    }
}

/// Garde `UserProfile.weightKg` sur la dernière tendance (spec M7 §14).
public enum ProfileWeightSync {
    /// Met `UserProfile.weightKg` sur la tendance (arrondie au dixième) s'il diffère ; rien sans tendance ni profil. Les 30 derniers
    /// jours suffisent à une tendance de 7 jours.
    public static func apply(measurements: any BodyMeasurementRepository, profiles: any ProfileRepository, now: Date,
                             calendar: Calendar) async throws {
        let today = calendar.startOfDay(for: now)
        let start = calendar.date(byAdding: .day, value: -30, to: today) ?? today
        let end = calendar.date(byAdding: .day, value: 1, to: today) ?? now
        let recent = try await measurements.measurements(from: start, to: end)
        guard let current = WeightTrend.make(measurements: recent, now: now, calendar: calendar).current,
              var profile = try await profiles.load() else { return }
        let rounded = (current * 10).rounded() / 10
        guard profile.weightKg != rounded else { return }
        profile.weightKg = rounded
        profile.updatedAt = now
        try await profiles.save(profile)
    }
}
