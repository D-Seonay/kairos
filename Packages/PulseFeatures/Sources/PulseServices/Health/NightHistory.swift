import Foundation
import PulseDomain
import PulseRecoveryEngine

/// Les nuits agrégées, et l'instant de la lecture Apple Santé qui les a produites (`nil` : reconstruites depuis le cache).
public struct NightHistorySnapshot: Sendable, Equatable {
    public var nights: [NightSample]
    public var readAt: Date?

    public init(nights: [NightSample], readAt: Date?) {
        self.nights = nights
        self.readAt = readAt
    }
}

/// Met à jour le cache local par lectures ancrées d'Apple Santé, un signal à la fois, puis agrège les 60 dernières nuits depuis ce cache.
/// La fréquence cardiaque brute, qui fait la FC de repos de la nuit, n'est lue que sur `NightSignal.heartRateHistoryDays` jours.
public struct NightHistory: Sendable {
    public static let historyDays = 60

    private let source: any HealthSampleSource
    private let cache: any HealthSampleCache
    private let calendar: Calendar

    public init(source: any HealthSampleSource, cache: any HealthSampleCache, calendar: Calendar) {
        self.source = source
        self.cache = cache
        self.calendar = calendar
    }

    private struct RawSamples {
        var sdnn: [TimedSample]
        var restingHeartRate: [TimedSample]
        var heartRate: [TimedSample]
        var sleep: [SleepInterval]
    }

    /// Chaque signal repart de l'ancre gardée dans le cache : sans ancre (premier lancement, cache de M3a) la lecture est complète et
    /// remplace le cache du signal, sinon elle n'apporte que les changements. Un signal qui échoue garde son ancre et son cache,
    /// les autres avancent, et `readAt` reste `nil`. Quand l'accès à Santé est révoqué, HealthKit ne signale aucune erreur : il ne
    /// renvoie rien de nouveau, et les nuits continuent d'être construites depuis le cache.
    public func refresh(now: Date, progress: @Sendable (Double) -> Void = { _ in }) async -> NightHistorySnapshot {
        let today = calendar.startOfDay(for: now)
        let start = calendar.date(byAdding: .day, value: -Self.historyDays, to: today) ?? today
        let end = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        let days = (0..<Self.historyDays).compactMap { calendar.date(byAdding: .day, value: $0 - (Self.historyDays - 1), to: today) }
        // La veille du plus ancien jour couvert : sa nuit commence le soir.
        let heartRateStart = calendar.date(byAdding: .day, value: -(NightSignal.heartRateHistoryDays + 1), to: today) ?? today

        var allSucceeded = true
        let signals = NightSignal.allCases
        for (index, signal) in signals.enumerated() {
            let succeeded = await sync(signal, from: signal == .heartRate ? heartRateStart : start, fetchedAt: now)
            allSucceeded = allSucceeded && succeeded
            progress(Double(index + 1) / Double(signals.count + 1))
        }
        progress(1)
        let raw = await cached(from: start, heartRateFrom: heartRateStart, to: end)
        let nights = NightAggregator(calendar: calendar).nights(
            days: days, sdnn: raw.sdnn, restingHeartRate: raw.restingHeartRate, heartRate: raw.heartRate, sleep: raw.sleep)
        return NightHistorySnapshot(nights: nights, readAt: allSucceeded ? now : nil)
    }

    /// Lit les changements d'un signal depuis l'ancre du cache et les y applique en une écriture ; vrai si les deux ont réussi.
    private func sync(_ signal: NightSignal, from start: Date, fetchedAt: Date) async -> Bool {
        let anchor = try? await cache.anchor(for: signal.kind)
        do {
            var changes = try await source.changes(of: signal, since: anchor, from: start)
            changes.added = changes.added.map { sample in
                var stamped = sample
                stamped.fetchedAt = fetchedAt
                return stamped
            }
            try await cache.apply(changes)
            return true
        } catch {
            return false
        }
    }

    private func cached(from: Date, heartRateFrom: Date, to: Date) async -> RawSamples {
        let sdnn = (try? await cache.samples(kind: .sdnn, from: from, to: to)) ?? []
        let restingHeartRate = (try? await cache.samples(kind: .restingHeartRate, from: from, to: to)) ?? []
        let heartRate = (try? await cache.samples(kind: .heartRate, from: heartRateFrom, to: to)) ?? []
        let sleep = (try? await cache.samples(kind: .sleep, from: from, to: to)) ?? []
        return RawSamples(sdnn: CachedSampleMapping.timedSamples(sdnn),
                          restingHeartRate: CachedSampleMapping.timedSamples(restingHeartRate),
                          heartRate: CachedSampleMapping.timedSamples(heartRate),
                          sleep: CachedSampleMapping.sleepIntervals(sleep))
    }
}
