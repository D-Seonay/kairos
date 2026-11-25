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
    /// Le plus vieux jour de référence de `change30Days`, en jours avant `lastMeasured`.
    public static let changeReferenceMaxDays = 37

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
    /// `current` moins la tendance du dernier jour mesuré entre 37 et 30 jours avant `lastMeasured` ; nul sans un tel jour, pour
    /// qu'« en 30 j » ne compare jamais à une pesée vieille de plusieurs mois.
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
              let oldest = calendar.date(byAdding: .day, value: -changeReferenceMaxDays, to: lastMeasured),
              let reference = points.last(where: { $0.date <= limit }), reference.date >= oldest else { return nil }
        return last.value - reference.value
    }
}

/// Garde `UserProfile.weightKg` sur le poids saisi dans Pulse (spec M7 §14, M8 §5.3) : le profil est synchronisé par iCloud, les
/// pesées Apple Santé ne le sont pas (M8a), donc aucune valeur d'Apple Santé n'y entre.
public enum ProfileWeightSync {
    /// Les jours d'une tendance : 7 jours de moyenne, 30 jours de lecture.
    private static let lookbackDays = 30

    /// Met `UserProfile.weightKg` sur la tendance (arrondie au dixième) des pesées **manuelles** des 30 derniers jours, faute de
    /// tendance sur le poids de la dernière pesée manuelle. Sans pesée manuelle, le poids est effacé si des pesées Apple Santé
    /// existent (il ne doit plus porter une valeur issue d'Apple Santé), et laissé tel quel sinon. N'écrit que si la valeur change ;
    /// rien sans profil.
    public static func apply(measurements: any BodyMeasurementRepository, profiles: any ProfileRepository, now: Date,
                             calendar: Calendar) async throws {
        let today = calendar.startOfDay(for: now)
        let start = calendar.date(byAdding: .day, value: -lookbackDays, to: today) ?? today
        let end = calendar.date(byAdding: .day, value: 1, to: today) ?? now
        let all = try await measurements.measurements(from: .distantPast, to: end)
        let manual = all.filter { $0.source == .manual && $0.weightKg != nil }
        let target: Double?
        if !manual.isEmpty {
            let recent = manual.filter { $0.date >= start }
            let latest = manual.max { lhs, rhs in lhs.date != rhs.date ? lhs.date < rhs.date : lhs.createdAt < rhs.createdAt }
            guard let weight = WeightTrend.make(measurements: recent, now: now, calendar: calendar).current ?? latest?.weightKg
            else { return }
            target = (weight * 10).rounded() / 10
        } else if all.contains(where: { $0.source == .appleHealth && $0.weightKg != nil }) {
            target = nil
        } else {
            return
        }
        try await profiles.update { profile in
            guard profile.weightKg != target else { return }
            profile.weightKg = target
            profile.updatedAt = now
        }
    }

    /// Le poids utilisé par les calculs (lu sur l'appareil, Apple Santé comprise) : la tendance de toutes les pesées des 30 derniers
    /// jours, sinon la dernière pesée, quelle que soit sa source et sa date (la pesée manuelle l'emporte le même jour), sinon le
    /// poids du profil.
    public static func currentWeight(measurements: any BodyMeasurementRepository, profiles: any ProfileRepository, now: Date,
                                     calendar: Calendar) async -> Double? {
        let today = calendar.startOfDay(for: now)
        let start = calendar.date(byAdding: .day, value: -lookbackDays, to: today) ?? today
        let end = calendar.date(byAdding: .day, value: 1, to: today) ?? now
        if let all = try? await measurements.measurements(from: .distantPast, to: end) {
            let recent = all.filter { $0.date >= start }
            if let current = WeightTrend.make(measurements: recent, now: now, calendar: calendar).current {
                return current
            }
            if let latest = WeightTrend.make(measurements: all, now: now, calendar: calendar).days.last {
                return latest.weightKg
            }
        }
        return (try? await profiles.load())?.weightKg
    }
}
