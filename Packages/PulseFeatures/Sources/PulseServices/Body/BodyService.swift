import Foundation
import PulseDomain

/// Le poids tel que l'écran Poids le montre : la tendance, les mesures de l'année et la présence de données Apple Santé.
public struct BodyOverview: Sendable, Equatable {
    public var trend: WeightTrend
    /// Les 365 derniers jours, plus récente d'abord.
    public var measurements: [BodyMeasurement]
    public var hasAppleHealthData: Bool

    public init(trend: WeightTrend, measurements: [BodyMeasurement], hasAppleHealthData: Bool) {
        self.trend = trend
        self.measurements = measurements
        self.hasAppleHealthData = hasAppleHealthData
    }
}

public enum BodyServiceError: Error, Equatable {
    case invalidWeight
    case notManual
}

/// Les pesées saisies dans Pulse (spec M7 §14). Chaque ajout, modification ou suppression remet `UserProfile.weightKg` sur la tendance.
public struct BodyService: Sendable {
    public static let weightRange = 20.0...400.0

    private let measurements: any BodyMeasurementRepository
    private let profiles: any ProfileRepository
    private let calendar: Calendar
    private let now: @Sendable () -> Date

    public init(measurements: any BodyMeasurementRepository, profiles: any ProfileRepository, calendar: Calendar,
                now: @escaping @Sendable () -> Date) {
        self.measurements = measurements
        self.profiles = profiles
        self.calendar = calendar
        self.now = now
    }

    public func overview() async throws -> BodyOverview {
        let today = calendar.startOfDay(for: now())
        let start = calendar.date(byAdding: .day, value: -BodyHistory.historyDays, to: today) ?? today
        let end = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        let all = try await measurements.measurements(from: start, to: end)
        let newestFirst = all.sorted { lhs, rhs in lhs.date != rhs.date ? lhs.date > rhs.date : lhs.createdAt > rhs.createdAt }
        return BodyOverview(trend: WeightTrend.make(measurements: all, now: now(), calendar: calendar), measurements: newestFirst,
                            hasAppleHealthData: all.contains { $0.source == .appleHealth })
    }

    public func addManual(weightKg: Double, date: Date) async throws {
        guard Self.weightRange.contains(weightKg) else { throw BodyServiceError.invalidWeight }
        let stamp = now()
        try await measurements.save(BodyMeasurement(date: date, weightKg: weightKg, source: .manual, createdAt: stamp, updatedAt: stamp))
        try await syncProfile()
    }

    /// Une mesure `.manual` seulement, sinon `.notManual`.
    public func updateManual(_ measurement: BodyMeasurement) async throws {
        guard measurement.source == .manual else { throw BodyServiceError.notManual }
        guard let weight = measurement.weightKg, Self.weightRange.contains(weight) else { throw BodyServiceError.invalidWeight }
        try await requireManual(id: measurement.id)
        var updated = measurement
        updated.updatedAt = now()
        try await measurements.save(updated)
        try await syncProfile()
    }

    /// Une mesure `.manual` seulement, sinon `.notManual`.
    public func deleteManual(id: UUID) async throws {
        try await requireManual(id: id)
        try await measurements.delete(id: id)
        try await syncProfile()
    }

    /// La mesure enregistrée sous cet identifiant, si elle existe, doit être manuelle : on ne modifie pas ce qu'Apple Santé a lu.
    private func requireManual(id: UUID) async throws {
        let stored = try await measurements.measurements(from: .distantPast, to: .distantFuture)
        if let existing = stored.first(where: { $0.id == id }), existing.source != .manual {
            throw BodyServiceError.notManual
        }
    }

    private func syncProfile() async throws {
        try await ProfileWeightSync.apply(measurements: measurements, profiles: profiles, now: now(), calendar: calendar)
    }
}
