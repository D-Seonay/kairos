import Foundation
import PulseDomain

/// Transforme des échantillons Apple Santé bruts en `NightSample` par jour de réveil (spec §6.1).
///
/// Toutes les bornes viennent du calendrier, jamais d'une arithmétique en secondes : la nuit du changement d'heure dure 25 h.
public struct NightAggregator: Sendable {
    /// Début de la fenêtre candidate de la nuit, en heures avant minuit du jour de réveil (18 h la veille).
    static let windowStartHours = NightWindow.startHours
    /// Fin de la fenêtre candidate, en heures après minuit (midi).
    static let windowEndHours = NightWindow.endHours
    /// Fenêtre SDNN de repli sans aucun sommeil enregistré : de minuit à 8 h. 8 h sert aussi de réveil supposé pour choisir
    /// l'échantillon Apple de FC au repos quand la nuit n'a pas de sommeil.
    static let fallbackSDNNHours = 8
    /// Le centile des fréquences cardiaques endormies qui fait la FC de repos de la nuit : le 5e, pour qu'une mesure isolée
    /// aberrante (montre qui glisse) ne fasse pas le minimum.
    static let overnightPercentile = 0.05
    /// Les fréquences cardiaques endormies plausibles, en bpm : sous 35, même chez un sportif d'endurance, c'est presque toujours
    /// une montre qui glisse ; au-dessus de 200, une erreur de capteur. Hors de cette plage, une mesure ne compte pas, ni pour le
    /// centile ni pour le minimum de mesures.
    static let plausibleHeartRate = 35.0...200.0
    /// Le nombre minimal de mesures de fréquence cardiaque endormies pour lire la FC de repos dans la nuit ; en dessous, on
    /// prend l'échantillon Apple le plus proche du réveil.
    static let overnightMinimumSamples = 5

    private let calendar: Calendar

    public init(calendar: Calendar) {
        self.calendar = calendar
    }

    /// `heartRate` : la fréquence cardiaque brute, d'où vient la FC de repos de la nuit quand elle couvre le sommeil.
    /// La fréquence cardiaque, des dizaines de milliers de mesures au premier lancement, est triée une fois : chaque nuit n'en lit
    /// ensuite que ses plages, par recherche dichotomique.
    public func nights(days: [Date], sdnn: [TimedSample], restingHeartRate: [TimedSample], heartRate: [TimedSample] = [],
                       sleep: [SleepInterval]) -> [NightSample] {
        let sortedHeartRate = heartRate.sorted { $0.date < $1.date }
        return days.map { night(for: $0, sdnn: sdnn, restingHeartRate: restingHeartRate, sortedHeartRate: sortedHeartRate, sleep: sleep) }
    }

    /// `day` est minuit local du jour de réveil. La SDNN de la nuit est la moyenne des mesures prises endormi dans le bloc
    /// principal : une sieste, un assoupissement du soir et les éveils n'y entrent pas. Sans mesure endormie, pas de SDNN.
    /// La FC de repos est la fréquence cardiaque la plus basse des mêmes plages (5e centile) ; sans assez de mesures, l'échantillon
    /// Apple « FC au repos » le plus proche du réveil, gardé dans tous les cas (`appleRestingHeartRate`) pour que la référence
    /// compare des valeurs de même source. Ni l'une ni l'autre ne bouge au fil de la matinée sans nouvelle nuit.
    public func night(for day: Date, sdnn: [TimedSample], restingHeartRate: [TimedSample], heartRate: [TimedSample] = [],
                      sleep: [SleepInterval]) -> NightSample {
        night(for: day, sdnn: sdnn, restingHeartRate: restingHeartRate, sortedHeartRate: heartRate.sorted { $0.date < $1.date },
              sleep: sleep)
    }

    private func night(for day: Date, sdnn: [TimedSample], restingHeartRate: [TimedSample], sortedHeartRate heartRate: [TimedSample],
                       sleep: [SleepInterval]) -> NightSample {
        let asleep = mergedAsleepIntervals(for: day, in: sleep)
        let detail = asleep.isEmpty ? nil : NightSleepBuilder(calendar: calendar).night(for: day, sleep: sleep)
        let sdnnWindows = asleep.isEmpty ? [fallbackWindow(for: day)] : mainBlockAsleepIntervals(of: detail)
        let sdnnValues = validSDNN(sdnn, in: sdnnWindows)
        let overnight = asleep.isEmpty ? nil : overnightLowest(heartRate, in: sdnnWindows)
        let wake = detail?.wokeUp ?? hours(Self.fallbackSDNNHours, from: day)
        let nearWake = appleRestingHeartRate(nearestTo: wake, in: restingHeartRate, on: day)

        return NightSample(
            day: day,
            sdnnMs: sdnnValues.isEmpty ? nil : sdnnValues.reduce(0, +) / Double(sdnnValues.count),
            sdnnSampleCount: sdnnValues.isEmpty ? nil : sdnnValues.count,
            restingHeartRate: overnight ?? nearWake,
            restingHeartRateSource: overnight != nil ? .overnightLowest : (nearWake != nil ? .appleNearWake : nil),
            appleRestingHeartRate: nearWake,
            sleep: summary(for: day, asleepIntervals: asleep, sleep: sleep, detail: detail)
        )
    }

    // MARK: - Sommeil

    private func retainedIntervals(for day: Date, in sleep: [SleepInterval]) -> [SleepInterval] {
        NightWindow.retainedAsleep(for: day, in: sleep, calendar: calendar)
    }

    private func mergedAsleepIntervals(for day: Date, in sleep: [SleepInterval]) -> [DateInterval] {
        merge(retainedIntervals(for: day, in: sleep).map { DateInterval(start: $0.start, end: $0.end) })
    }

    /// Les plages endormies du bloc principal de la nuit, fusionnées : les éveils et les trous sans donnée en sont exclus.
    private func mainBlockAsleepIntervals(of night: NightSleep?) -> [DateInterval] {
        merge((night?.segments ?? []).filter { $0.stage.isAsleep }.map { DateInterval(start: $0.start, end: $0.end) })
    }

    /// Le total et le profond gardent leur calcul (ils font le score) ; les autres phases viennent de `NightSleepBuilder`
    /// (`detail`), qui compte les mêmes minutes endormies et profondes.
    private func summary(for day: Date, asleepIntervals: [DateInterval], sleep: [SleepInterval], detail: NightSleep?) -> SleepSummary? {
        guard !asleepIntervals.isEmpty else { return nil }
        let retained = retainedIntervals(for: day, in: sleep)
        let hasStages = retained.contains { [.core, .deep, .rem].contains($0.stage) }
        let deep = merge(retained.filter { $0.stage == .deep }.map { DateInterval(start: $0.start, end: $0.end) })
        guard hasStages, let night = detail else {
            return SleepSummary(asleepMinutes: minutes(asleepIntervals), deepMinutes: hasStages ? minutes(deep) : nil)
        }
        return SleepSummary(asleepMinutes: minutes(asleepIntervals), deepMinutes: minutes(deep), coreMinutes: night.coreMinutes,
                            remMinutes: night.remMinutes, unspecifiedMinutes: night.unspecifiedMinutes,
                            awakeMinutes: night.awakeMinutes)
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

    /// Les mesures valides qui tombent dans l'une des plages.
    private func validSDNN(_ samples: [TimedSample], in windows: [DateInterval]) -> [Double] {
        samples
            .filter { sample in HRVBaseline.isValid(sdnnMs: sample.value) && windows.contains { $0.contains(sample.date) } }
            .map(\.value)
    }

    /// Le 5e centile des fréquences cardiaques plausibles prises endormi, interpolé entre les deux rangs voisins (sur 10 mesures,
    /// à 45 % entre la plus basse et la suivante : pas simplement la plus basse) ; `nil` sous `overnightMinimumSamples`.
    /// `samples` est trié par date.
    private func overnightLowest(_ samples: [TimedSample], in windows: [DateInterval]) -> Double? {
        let values = windows
            .flatMap { window in samples[firstIndex(in: samples, notBefore: window.start)...].prefix { $0.date <= window.end } }
            .map(\.value)
            .filter { Self.plausibleHeartRate.contains($0) }
            .sorted()
        guard values.count >= Self.overnightMinimumSamples else { return nil }
        let position = Self.overnightPercentile * Double(values.count - 1)
        let lower = Int(position.rounded(.down))
        let upper = min(lower + 1, values.count - 1)
        return values[lower] + (position - Double(lower)) * (values[upper] - values[lower])
    }

    /// L'indice de la première mesure à `date` ou après, dans des mesures triées par date.
    private func firstIndex(in samples: [TimedSample], notBefore date: Date) -> Int {
        var low = 0
        var high = samples.count
        while low < high {
            let middle = (low + high) / 2
            if samples[middle].date < date { low = middle + 1 } else { high = middle }
        }
        return low
    }

    /// L'échantillon Apple du jour (de minuit à minuit) le plus proche de `wake` ; à égalité, le plus tôt.
    private func appleRestingHeartRate(nearestTo wake: Date, in samples: [TimedSample], on day: Date) -> Double? {
        guard let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else { return nil }
        return samples
            .filter { $0.date >= day && $0.date < nextDay }
            .min { lhs, rhs in
                let left = abs(lhs.date.timeIntervalSince(wake))
                let right = abs(rhs.date.timeIntervalSince(wake))
                return left == right ? lhs.date < rhs.date : left < right
            }?
            .value
    }

    private func hours(_ hours: Int, from date: Date) -> Date {
        calendar.date(byAdding: .hour, value: hours, to: date) ?? date.addingTimeInterval(Double(hours) * 3600)
    }
}
