import Foundation
import PulseDomain
import PulseRecoveryEngine

/// La moyenne par phase des nuits avec phases qui précèdent une nuit (au plus `NightDetailService.averagedNights`).
public struct StageAverages: Sendable, Equatable {
    public var deep: Double
    public var core: Double
    public var rem: Double
    public var awake: Double
    public var nights: Int

    public init(deep: Double, core: Double, rem: Double, awake: Double, nights: Int) {
        self.deep = deep
        self.core = core
        self.rem = rem
        self.awake = awake
        self.nights = nights
    }
}

/// Une nuit de l'écran Nuit, et la moyenne à laquelle la comparer (nulle sans nuit à phases avant elle, ou sans phases elle-même).
public struct NightDetail: Sendable, Equatable, Identifiable {
    public var night: NightSleep
    public var averages: StageAverages?

    public var id: Date { night.day }

    public init(night: NightSleep, averages: StageAverages?) {
        self.night = night
        self.averages = averages
    }
}

/// Les nuits de l'écran Nuit, reconstituées depuis le cache local (spec sommeil §6.3). Ne lit jamais Apple Santé : le passage du
/// jour tient le cache à jour.
public struct NightDetailService: Sendable {
    /// Le nombre de nuits avec phases moyennées avant chaque nuit.
    public static let averagedNights = 14

    private let cache: any HealthSampleCache
    private let calendar: Calendar
    private let now: @Sendable () -> Date

    public init(cache: any HealthSampleCache, calendar: Calendar, now: @escaping @Sendable () -> Date) {
        self.cache = cache
        self.calendar = calendar
        self.now = now
    }

    /// Les nuits avec sommeil dont le réveil tombe dans les `NightHistory.historyDays` derniers jours, chronologiques.
    /// Une lecture du cache qui échoue rend une liste vide.
    public func nights() async -> [NightDetail] {
        let today = calendar.startOfDay(for: now())
        guard let start = calendar.date(byAdding: .day, value: -(NightHistory.historyDays + 2), to: today),
              let end = calendar.date(byAdding: .day, value: 1, to: today),
              let cached = try? await cache.samples(kind: .sleep, from: start, to: end) else { return [] }
        let sleep = CachedSampleMapping.sleepIntervals(cached)
        let builder = NightSleepBuilder(calendar: calendar)
        let nights = (0..<NightHistory.historyDays).compactMap { offset -> NightSleep? in
            guard let day = calendar.date(byAdding: .day, value: offset - (NightHistory.historyDays - 1), to: today) else { return nil }
            return builder.night(for: day, sleep: sleep)
        }
        return nights.indices.map { index in
            NightDetail(night: nights[index], averages: averages(before: index, in: nights))
        }
    }

    private func averages(before index: Int, in nights: [NightSleep]) -> StageAverages? {
        guard nights[index].hasStages else { return nil }
        let previous = nights[..<index].filter(\.hasStages).suffix(Self.averagedNights)
        guard !previous.isEmpty else { return nil }
        let count = Double(previous.count)
        func mean(_ value: (NightSleep) -> Int) -> Double {
            Double(previous.reduce(0) { $0 + value($1) }) / count
        }
        return StageAverages(deep: mean(\.deepMinutes), core: mean(\.coreMinutes), rem: mean(\.remMinutes),
                             awake: mean(\.awakeMinutes), nights: previous.count)
    }
}
