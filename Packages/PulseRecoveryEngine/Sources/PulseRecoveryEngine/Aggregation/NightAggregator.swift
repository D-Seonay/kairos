import Foundation
import PulseDomain

/// Transforme des échantillons Apple Santé bruts en `NightSample` par jour de réveil (spec §6.1).
///
/// Toutes les bornes viennent du calendrier, jamais d'une arithmétique en secondes : la nuit du changement d'heure dure 25 h.
public struct NightAggregator: Sendable {
    /// Début de la fenêtre candidate de la nuit, en heures avant minuit du jour de réveil (18 h la veille).
    static let windowStartHours = -6
    /// Fin de la fenêtre candidate, en heures après minuit (midi).
    static let windowEndHours = 12
    /// Fenêtre SDNN de repli sans sommeil délimité : de minuit à 8 h.
    static let fallbackSDNNHours = 8

    private let calendar: Calendar

    public init(calendar: Calendar) {
        self.calendar = calendar
    }

    public func nights(days: [Date], sdnn: [TimedSample], restingHeartRate: [TimedSample], sleep: [SleepInterval]) -> [NightSample] {
        days.map { night(for: $0, sdnn: sdnn, restingHeartRate: restingHeartRate, sleep: sleep) }
    }

    /// `day` est minuit local du jour de réveil.
    public func night(for day: Date, sdnn: [TimedSample], restingHeartRate: [TimedSample], sleep: [SleepInterval]) -> NightSample {
        let asleep = mergedAsleepIntervals(for: day, in: sleep)
        let sleepWindow = asleep.isEmpty ? fallbackWindow(for: day) : DateInterval(start: asleep[0].start, end: asleep[asleep.count - 1].end)

        return NightSample(
            day: day,
            sdnnMs: meanSDNN(sdnn, in: sleepWindow),
            restingHeartRate: lastRestingHeartRate(restingHeartRate, on: day),
            sleep: summary(asleepIntervals: asleep, retained: retainedIntervals(for: day, in: sleep))
        )
    }

    // MARK: - Sommeil

    private func retainedIntervals(for day: Date, in sleep: [SleepInterval]) -> [SleepInterval] {
        let start = hours(Self.windowStartHours, from: day)
        let end = hours(Self.windowEndHours, from: day)
        return sleep.filter { $0.stage.isAsleep && $0.end >= start && $0.end <= end && $0.end > $0.start }
    }

    private func mergedAsleepIntervals(for day: Date, in sleep: [SleepInterval]) -> [DateInterval] {
        merge(retainedIntervals(for: day, in: sleep).map { DateInterval(start: $0.start, end: $0.end) })
    }

    private func summary(asleepIntervals: [DateInterval], retained: [SleepInterval]) -> SleepSummary? {
        guard !asleepIntervals.isEmpty else { return nil }
        let hasStages = retained.contains { [.core, .deep, .rem].contains($0.stage) }
        let deep = merge(retained.filter { $0.stage == .deep }.map { DateInterval(start: $0.start, end: $0.end) })
        return SleepSummary(asleepMinutes: minutes(asleepIntervals), deepMinutes: hasStages ? minutes(deep) : nil)
    }

    /// Union d'intervalles : tri par début, fusion des chevauchements et des contacts.
    private func merge(_ intervals: [DateInterval]) -> [DateInterval] {
        var merged: [DateInterval] = []
        for interval in intervals.sorted(by: { $0.start < $1.start }) {
            if let last = merged.last, interval.start <= last.end {
                merged[merged.count - 1] = DateInterval(start: last.start, end: max(last.end, interval.end))
            } else {
                merged.append(interval)
            }
        }
        return merged
    }

    private func minutes(_ intervals: [DateInterval]) -> Int {
        Int((intervals.reduce(0) { $0 + $1.duration } / 60).rounded())
    }

    // MARK: - SDNN et FC repos

    private func fallbackWindow(for day: Date) -> DateInterval {
        DateInterval(start: day, end: hours(Self.fallbackSDNNHours, from: day))
    }

    private func meanSDNN(_ samples: [TimedSample], in window: DateInterval) -> Double? {
        let values = samples
            .filter { window.contains($0.date) && HRVBaseline.isValid(sdnnMs: $0.value) }
            .map(\.value)
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private func lastRestingHeartRate(_ samples: [TimedSample], on day: Date) -> Double? {
        guard let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else { return nil }
        return samples
            .filter { $0.date >= day && $0.date < nextDay }
            .max(by: { $0.date < $1.date })?
            .value
    }

    private func hours(_ hours: Int, from date: Date) -> Date {
        calendar.date(byAdding: .hour, value: hours, to: date) ?? date.addingTimeInterval(Double(hours) * 3600)
    }
}
