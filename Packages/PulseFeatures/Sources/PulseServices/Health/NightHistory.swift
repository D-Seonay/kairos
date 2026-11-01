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

/// Lit 60 jours d'échantillons bruts, met à jour le cache local et agrège les nuits ; se replie sur le cache si la lecture échoue.
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
        var sleep: [SleepInterval]
    }

    /// Une lecture qui aboutit remplace le cache, même vide. Quand l'accès à Santé est révoqué, HealthKit ne signale aucune
    /// erreur : il répond sans échantillon, le cache est vidé et `readAt` est renseigné. C'est voulu : l'utilisateur retombe
    /// sur le check-in, et le score déjà enregistré pour aujourd'hui est conservé par `DailyScoreService`.
    public func refresh(now: Date, progress: @Sendable (Double) -> Void = { _ in }) async -> NightHistorySnapshot {
        let today = calendar.startOfDay(for: now)
        let start = calendar.date(byAdding: .day, value: -Self.historyDays, to: today) ?? today
        let end = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        let days = (0..<Self.historyDays).compactMap { calendar.date(byAdding: .day, value: $0 - (Self.historyDays - 1), to: today) }

        let raw: RawSamples
        let readAt: Date?
        do {
            raw = try await read(from: start, to: end, progress: progress)
            await store(raw, fetchedAt: now)
            readAt = now
        } catch {
            raw = await cached(from: start, to: end)
            readAt = nil
        }
        progress(1)
        let nights = NightAggregator(calendar: calendar)
            .nights(days: days, sdnn: raw.sdnn, restingHeartRate: raw.restingHeartRate, sleep: raw.sleep)
        return NightHistorySnapshot(nights: nights, readAt: readAt)
    }

    private func read(from: Date, to: Date, progress: @Sendable (Double) -> Void) async throws -> RawSamples {
        let sdnn = try await source.sdnnSamples(from: from, to: to)
        progress(0.25)
        let restingHeartRate = try await source.restingHeartRateSamples(from: from, to: to)
        progress(0.5)
        let sleep = try await source.sleepIntervals(from: from, to: to)
        progress(0.75)
        return RawSamples(sdnn: sdnn, restingHeartRate: restingHeartRate, sleep: sleep)
    }

    /// Le cache est un confort : une écriture qui échoue n'invalide pas la lecture qui vient de réussir.
    private func store(_ raw: RawSamples, fetchedAt: Date) async {
        try? await cache.replace(kind: .sdnn, with: CachedSampleMapping.cached(raw.sdnn, kind: .sdnn, fetchedAt: fetchedAt))
        try? await cache.replace(kind: .restingHeartRate,
                                 with: CachedSampleMapping.cached(raw.restingHeartRate, kind: .restingHeartRate, fetchedAt: fetchedAt))
        try? await cache.replace(kind: .sleep, with: CachedSampleMapping.cached(raw.sleep, fetchedAt: fetchedAt))
    }

    private func cached(from: Date, to: Date) async -> RawSamples {
        let sdnn = (try? await cache.samples(kind: .sdnn, from: from, to: to)) ?? []
        let restingHeartRate = (try? await cache.samples(kind: .restingHeartRate, from: from, to: to)) ?? []
        let sleep = (try? await cache.samples(kind: .sleep, from: from, to: to)) ?? []
        return RawSamples(sdnn: CachedSampleMapping.timedSamples(sdnn),
                          restingHeartRate: CachedSampleMapping.timedSamples(restingHeartRate),
                          sleep: CachedSampleMapping.sleepIntervals(sleep))
    }
}
