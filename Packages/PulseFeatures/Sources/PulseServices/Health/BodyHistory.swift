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
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
        var changed = false
        for signal in BodySignal.allCases {
            guard await sync(signal, from: start, to: end, fetchedAt: now) else { continue }
            changed = await align(signal, from: start, to: end, now: now) || changed
        }
        // `UserProfile.weightKg` suit les pesées manuelles, à chaque passage et pas seulement quand une mesure change : le
        // déplacement des pesées Apple Santé hors d'iCloud peut avoir eu lieu sans que ce passage n'ajoute rien. Un échec ici ne
        // change pas ce que le passage rend.
        try? await ProfileWeightSync.apply(measurements: measurements, profiles: profiles, now: now, calendar: calendar)
        return changed
    }

    private func sync(_ signal: BodySignal, from start: Date, to end: Date, fetchedAt: Date) async -> Bool {
        // Une fenêtre lue plus étroite que celle d'aujourd'hui (ou rien) : l'ancre est ignorée et la lecture est complète. La
        // fenêtre n'est retenue qu'une fois le cache écrit, donc un échec est retenté.
        let windowIsCurrent = (windows.days(for: signal.kind) ?? 0) >= Self.historyDays
        let anchor = windowIsCurrent ? try? await cache.anchor(for: signal.kind) : nil
        do {
            var changes = try await source.bodyChanges(of: signal, since: anchor, from: start)
            // Apple Santé ne distingue pas un accès révoqué de pesées effacées : une lecture complète qui ne rend rien alors que le
            // cache en gardait ne doit pas emporter les mesures importées. Le cache et les mesures importées sont tous deux locaux, mais
            // le cache peut être vidé sans le magasin local (réinstallation partielle, cache purgé) : les mesures importées sont
            // alors là et le cache est vide. Dans les deux cas rien n'est appliqué ni retenu, la lecture est retentée.
            if changes.isFullRead, changes.added.isEmpty {
                let cached = try await cache.samples(kind: signal.kind, from: .distantPast, to: .distantFuture)
                if !cached.isEmpty { return false }
                let stored = try await measurements.measurements(from: start, to: end)
                if stored.contains(where: { Self.isImported($0, signal: signal) }) { return false }
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
    private func align(_ signal: BodySignal, from start: Date, to end: Date, now: Date) async -> Bool {
        guard let samples = try? await cache.samples(kind: signal.kind, from: start, to: end),
              let stored = try? await measurements.measurements(from: start, to: end) else { return false }
        let imported = stored.filter { Self.isImported($0, signal: signal) }
        // Deux appareils qui importent la même pesée avant de se synchroniser en font deux mesures : la plus ancienne est gardée.
        let (byUUID, duplicates) = HealthImportDuplicates.split(imported, uuid: \.healthKitUUID) { $0.createdAt < $1.createdAt }
        var changed = await delete(duplicates.map(\.id))
        var seen = Set<String>()
        for sample in samples {
            guard let uuid = sample.healthKitUUID, sample.value != nil, seen.insert(uuid).inserted else { continue }
            let measurement = Self.measurement(from: sample, signal: signal, existing: byUUID[uuid], now: now)
            guard measurement != byUUID[uuid] else { continue }
            if (try? await measurements.save(measurement)) != nil { changed = true }
        }
        // Les mesures gardées dont l'échantillon n'est plus dans le cache (effacé dans Apple Santé), et celles sans identifiant.
        let gone = byUUID.filter { !seen.contains($0.key) }.values.map(\.id) + imported.filter { $0.healthKitUUID == nil }.map(\.id)
        return await delete(gone) || changed
    }

    /// Rend vrai si au moins une mesure a été supprimée.
    private func delete(_ ids: [UUID]) async -> Bool {
        var deleted = false
        for id in ids.sorted(by: { $0.uuidString < $1.uuidString }) {
            deleted = (try? await measurements.delete(id: id)) != nil || deleted
        }
        return deleted
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

    /// Une mesure importée d'Apple Santé qui porte une valeur du signal.
    private static func isImported(_ measurement: BodyMeasurement, signal: BodySignal) -> Bool {
        measurement.source == .appleHealth && value(of: measurement, signal: signal) != nil
    }

    private static func value(of measurement: BodyMeasurement, signal: BodySignal) -> Double? {
        switch signal {
        case .bodyMass: measurement.weightKg
        case .bodyFat: measurement.bodyFatPercent
        }
    }
}
