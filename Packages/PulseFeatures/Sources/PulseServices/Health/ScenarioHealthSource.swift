import Foundation
import PulseDomain

/// Source Apple Santé factice et déterministe : 60 nuits finissant au jour de `now`, selon un `HealthScenario`.
///
/// L'ancre est le jour des données générées, en texte (`"2026-11-02"`) : la même ancre ne ramène rien, une autre ramène tout.
public struct ScenarioHealthSource: HealthSampleSource {
    static let nightCount = 60

    private let samples: [HealthSampleKind: [CachedHealthSample]]
    private let dayAnchor: Data
    private let hints: HealthProfileHints

    public init(scenario: HealthScenario, now: Date, calendar: Calendar) {
        let today = calendar.startOfDay(for: now)
        var builder = Builder(calendar: calendar)
        for index in 0..<Self.nightCount where Self.includesNight(index, in: scenario) {
            let day = calendar.date(byAdding: .day, value: index - (Self.nightCount - 1), to: today) ?? today
            let night = index == Self.nightCount - 1 ? Self.todayNight(for: scenario) : Self.historyNight(index)
            builder.add(night, on: day)
        }
        samples = builder.samples
        dayAnchor = Data(Self.dayText(today, calendar: calendar).utf8)
        hints = scenario == .noData ? HealthProfileHints() : Self.hints(calendar: calendar)
    }

    public func requestAuthorization() async throws {}

    /// Sans ancre, ou avec l'ancre d'un autre jour : tous les échantillons commençant à `start` ou après. Avec l'ancre du jour : rien.
    public func changes(of signal: NightSignal, since anchor: Data?, from start: Date) async throws -> HealthSampleChanges {
        guard anchor != dayAnchor else {
            return HealthSampleChanges(kind: signal.kind, added: [], deletedHealthKitUUIDs: [], anchor: dayAnchor, isFullRead: false)
        }
        let added = (samples[signal.kind] ?? []).filter { $0.start >= start }
        return HealthSampleChanges(kind: signal.kind, added: added, deletedHealthKitUUIDs: [], anchor: dayAnchor, isFullRead: true)
    }

    public func profileHints() async throws -> HealthProfileHints {
        hints
    }

    private static func dayText(_ day: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: day)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    // MARK: - Nuits

    /// Les mesures d'une nuit. Les minutes sont comptées depuis minuit du jour de réveil (négatif : la veille).
    struct Night {
        var sdnnMs: Double?
        var restingHeartRate: Double
        var sleepStartMinute: Int
        var stages: [(stage: SleepStage, minutes: Int)]
    }

    private static let sdnnMinutes = [60, 180, 300]
    private static let restingHeartRateMinute = 450
    private static let wakeMinute = 420

    private static func includesNight(_ index: Int, in scenario: HealthScenario) -> Bool {
        switch scenario {
        case .noData: false
        case .threeNights: index >= nightCount - 3
        case .goodNight, .badNight, .missingHRV: true
        }
    }

    /// 23 h → 7 h : 480 minutes dont 96 de sommeil profond.
    private static let fullNightStages: [(stage: SleepStage, minutes: Int)] = [
        (.core, 90), (.deep, 96), (.core, 114), (.rem, 90), (.core, 90)
    ]

    private static func historyNight(_ index: Int) -> Night {
        Night(sdnnMs: Double(50 + 2 * ((index % 5) - 2)), restingHeartRate: Double(50 + ((index % 3) - 1)),
              sleepStartMinute: wakeMinute - 480, stages: fullNightStages)
    }

    private static func todayNight(for scenario: HealthScenario) -> Night {
        switch scenario {
        case .badNight:
            Night(sdnnMs: 46, restingHeartRate: 55, sleepStartMinute: wakeMinute - 310,
                  stages: [(.core, 100), (.deep, 22), (.core, 120), (.rem, 68)])
        case .missingHRV:
            Night(sdnnMs: nil, restingHeartRate: 48, sleepStartMinute: wakeMinute - 480, stages: fullNightStages)
        case .goodNight, .threeNights, .noData:
            Night(sdnnMs: 56, restingHeartRate: 48, sleepStartMinute: wakeMinute - 480, stages: fullNightStages)
        }
    }

    private static func hints(calendar: Calendar) -> HealthProfileHints {
        let birth = calendar.date(from: DateComponents(year: 1998, month: 3, day: 14))
        return HealthProfileHints(sex: .male, birthDate: birth, heightCm: 178, weightKg: 74.5)
    }

    private struct Builder {
        let calendar: Calendar
        var samples: [HealthSampleKind: [CachedHealthSample]] = [:]

        mutating func add(_ night: Night, on day: Date) {
            if let value = night.sdnnMs {
                for minute in ScenarioHealthSource.sdnnMinutes {
                    append(.sdnn, start: moment(day, minute), end: moment(day, minute), value: value)
                }
            }
            let measuredAt = moment(day, ScenarioHealthSource.restingHeartRateMinute)
            append(.restingHeartRate, start: measuredAt, end: measuredAt, value: night.restingHeartRate)
            var minute = night.sleepStartMinute
            for (stage, minutes) in night.stages {
                append(.sleep, start: moment(day, minute), end: moment(day, minute + minutes), stage: stage)
                minute += minutes
            }
        }

        /// Les UUID suivent l'ordre de génération de chaque type : `scenario.sdnn.0`, `scenario.sdnn.1`…
        private mutating func append(_ kind: HealthSampleKind, start: Date, end: Date, value: Double? = nil, stage: SleepStage? = nil) {
            let uuid = "scenario.\(kind.rawValue).\(samples[kind, default: []].count)"
            samples[kind, default: []].append(CachedHealthSample(
                kind: kind, start: start, end: end, value: value, sleepStage: stage, healthKitUUID: uuid, fetchedAt: end))
        }

        private func moment(_ day: Date, _ minutes: Int) -> Date {
            calendar.date(byAdding: .minute, value: minutes, to: day) ?? day
        }
    }
}
