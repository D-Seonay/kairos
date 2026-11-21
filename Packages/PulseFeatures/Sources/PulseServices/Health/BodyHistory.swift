import Foundation
import PulseDomain

/// Lit le poids et la masse grasse d'Apple Santé dans le cache local, puis les aligne sur les mesures (spec M7 §14), comme
/// `WorkoutHistory` le fait pour les courses : un échantillon nouveau devient une mesure `appleHealth`, un échantillon effacé dans
/// Apple Santé emporte sa mesure. Les mesures saisies dans Pulse ne sont jamais lues ni écrites.
public struct BodyHistory: Sendable {
    /// La fenêtre lue : un an, comme les courses.
    public static let historyDays = 365

    private let source: any HealthBodySource
    private let cache: any HealthSampleCache
    private let measurements: any BodyMeasurementRepository
    private let profiles: any ProfileRepository
    private let windows: any HealthReadWindowStore
    private let calendar: Calendar

    public init(source: any HealthBodySource, cache: any HealthSampleCache, measurements: any BodyMeasurementRepository,
                profiles: any ProfileRepository, windows: any HealthReadWindowStore, calendar: Calendar) {
        self.source = source
        self.cache = cache
        self.measurements = measurements
        self.profiles = profiles
        self.windows = windows
        self.calendar = calendar
    }

    /// Un signal à la fois : un signal dont la lecture ou l'écriture du cache échoue garde ses mesures telles quelles. Rend vrai si
    /// une mesure a été ajoutée, modifiée ou supprimée.
    @discardableResult
    public func refresh(now: Date) async -> Bool {
        let start = calendar.date(byAdding: .day, value: -Self.historyDays, to: calendar.startOfDay(for: now)) ?? now
        var changed = false
        for signal in BodySignal.allCases {
            guard await sync(signal, from: start, fetchedAt: now) else { continue }
            changed = await align(signal, from: start, now: now) || changed
        }
        // `UserProfile.weightKg` suit la tendance : un échec ici ne change pas ce que le passage rend.
        if changed {
            try? await ProfileWeightSync.apply(measurements: measurements, profiles: profiles, now: now, calendar: calendar)
        }
        return changed
    }

    private func sync(_ signal: BodySignal, from start: Date, fetchedAt: Date) async -> Bool {
        // Une fenêtre lue plus étroite que celle d'aujourd'hui (ou rien) : l'ancre est ignorée et la lecture est complète. La
        // fenêtre n'est retenue qu'une fois le cache écrit, donc un échec est retenté.
        let windowIsCurrent = (windows.days(for: signal.kind) ?? 0) >= Self.historyDays
        let anchor = windowIsCurrent ? try? await cache.anchor(for: signal.kind) : nil
        do {
            var changes = try await source.bodyChanges(of: signal, since: anchor, from: start)
            // Apple Santé ne distingue pas un accès révoqué de pesées effacées : une lecture complète qui ne rend rien alors que le
            // cache en gardait ne doit pas emporter les mesures importées. Rien n'est appliqué ni retenu, elle est retentée.
            if changes.isFullRead, changes.added.isEmpty {
                let cached = try await cache.samples(kind: signal.kind, from: .distantPast, to: .distantFuture)
                if !cached.isEmpty { return false }
            }
            changes.added = changes.added.map { sample in
                var stamped = sample
                stamped.fetchedAt = fetchedAt
                return stamped
            }
            try await cache.apply(changes)
            windows.save(days: Self.historyDays, for: signal.kind)
            return true
        } catch {
            return false
        }
    }

    /// Ajoute, met à jour ou supprime les mesures `appleHealth` du signal datées dans la fenêtre pour qu'elles suivent le cache.
    private func align(_ signal: BodySignal, from start: Date, now: Date) async -> Bool {
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
        guard let samples = try? await cache.samples(kind: signal.kind, from: start, to: end),
              let stored = try? await measurements.measurements(from: start, to: end) else { return false }
        let imported = stored.filter { $0.source == .appleHealth && Self.value(of: $0, signal: signal) != nil }
        var byUUID = [String: BodyMeasurement]()
        for measurement in imported {
            if let uuid = measurement.healthKitUUID { byUUID[uuid] = measurement }
        }
        var changed = false
        var seen = Set<String>()
        for sample in samples {
            guard let uuid = sample.healthKitUUID, sample.value != nil, seen.insert(uuid).inserted else { continue }
            let measurement = Self.measurement(from: sample, signal: signal, existing: byUUID[uuid], now: now)
            guard measurement != byUUID[uuid] else { continue }
            if (try? await measurements.save(measurement)) != nil { changed = true }
        }
        for measurement in imported where measurement.healthKitUUID.map({ !seen.contains($0) }) ?? true {
            if (try? await measurements.delete(id: measurement.id)) != nil { changed = true }
        }
        return changed
    }

    /// La mesure d'un échantillon lu. Une mesure existante garde son identifiant et sa création ; seuls la date et la valeur
    /// lues d'Apple Santé la suivent.
    static func measurement(from sample: CachedHealthSample, signal: BodySignal, existing: BodyMeasurement?, now: Date) -> BodyMeasurement {
        var measurement = existing ?? BodyMeasurement(date: sample.start, source: .appleHealth, createdAt: now, updatedAt: now)
        let previous = measurement
        measurement.date = sample.start
        switch signal {
        case .bodyMass: measurement.weightKg = sample.value
        case .bodyFat: measurement.bodyFatPercent = sample.value
        }
        measurement.healthKitUUID = sample.healthKitUUID
        if existing != nil, measurement != previous { measurement.updatedAt = now }
        return measurement
    }

    private static func value(of measurement: BodyMeasurement, signal: BodySignal) -> Double? {
        switch signal {
        case .bodyMass: measurement.weightKg
        case .bodyFat: measurement.bodyFatPercent
        }
    }
}
