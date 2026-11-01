import Foundation
import PulseDomain

/// Source Apple Santé factice et déterministe : 60 nuits finissant au jour de `now`, selon un `HealthScenario`.
public struct ScenarioHealthSource: HealthSampleSource {
    static let nightCount = 60

    private let sdnn: [TimedSample]
    private let restingHeartRate: [TimedSample]
    private let sleep: [SleepInterval]
    private let hints: HealthProfileHints

    public init(scenario: HealthScenario, now: Date, calendar: Calendar) {
        let today = calendar.startOfDay(for: now)
        var builder = Builder(calendar: calendar)
        for index in 0..<Self.nightCount where Self.includesNight(index, in: scenario) {
            let day = calendar.date(byAdding: .day, value: index - (Self.nightCount - 1), to: today) ?? today
            let night = index == Self.nightCount - 1 ? Self.todayNight(for: scenario) : Self.historyNight(index)
            builder.add(night, on: day)
        }
        sdnn = builder.sdnn
        restingHeartRate = builder.restingHeartRate
        sleep = builder.sleep
        hints = scenario == .noData ? HealthProfileHints() : Self.hints(calendar: calendar)
    }

    public func requestAuthorization() async throws {}

    public func sdnnSamples(from: Date, to: Date) async throws -> [TimedSample] {
        sdnn.filter { $0.date >= from && $0.date < to }
    }

    public func restingHeartRateSamples(from: Date, to: Date) async throws -> [TimedSample] {
        restingHeartRate.filter { $0.date >= from && $0.date < to }
    }

    public func sleepIntervals(from: Date, to: Date) async throws -> [SleepInterval] {
        sleep.filter { $0.end > from && $0.start < to }
    }

    public func profileHints() async throws -> HealthProfileHints {
        hints
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
        var sdnn: [TimedSample] = []
        var restingHeartRate: [TimedSample] = []
        var sleep: [SleepInterval] = []

        mutating func add(_ night: Night, on day: Date) {
            if let value = night.sdnnMs {
                sdnn += ScenarioHealthSource.sdnnMinutes.map { TimedSample(date: moment(day, $0), value: value) }
            }
            restingHeartRate.append(TimedSample(date: moment(day, ScenarioHealthSource.restingHeartRateMinute),
                                                value: night.restingHeartRate))
            var minute = night.sleepStartMinute
            for (stage, minutes) in night.stages {
                sleep.append(SleepInterval(start: moment(day, minute), end: moment(day, minute + minutes), stage: stage))
                minute += minutes
            }
        }

        private func moment(_ day: Date, _ minutes: Int) -> Date {
            calendar.date(byAdding: .minute, value: minutes, to: day) ?? day
        }
    }
}
