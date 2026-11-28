import Foundation
import PulseDomain

extension RecoveryCalculator {
    struct PartialFactor {
        let factor: Factor
        let score: Double
        let todayValue: Double
        let baselineValue: Double?
    }

    /// Les nuits de la ligne de base VFC : celles retenues, et celles écartées faute d'assez de mesures.
    struct HRVNights {
        var values: [Double]
        var used: Int { values.count >= HRVBaseline.minimumNights ? values.count : 0 }
        var setAside: Int
    }

    /// Le facteur VFC (absent sans ligne de base ou sans SDNN valide), l'état de la calibration et les nuits de la ligne de base.
    struct HRVFactor {
        var score: PartialFactor?
        var calibration: CalibrationState
        var nights: HRVNights
    }

    // MARK: - VFC

    /// La ligne de base vient des nuits valides des 14 jours d'avant ; la calibration, de celles des 28 jours d'avant :
    /// prête dès 14 nuits valides, sinon en cours avec ce nombre de nuits (13 au plus). La calibration compte toutes les nuits
    /// valides, même peu mesurées : la règle de #111 ne change pas.
    func hrvFactor(day: Date, today: NightSample, history: [NightSample]) -> HRVFactor {
        let selection = hrvNights(day: day, history: history)
        let calibrationNights = validSDNN(nights(of: history, before: day, days: Self.calibrationWindowDays)).count
        let calibration: CalibrationState = calibrationNights < Self.calibrationNights ? .calibrating(nights: calibrationNights) : .ready

        guard let baseline = HRVBaseline(sdnnValuesMs: selection.values),
              let sdnn = today.sdnnMs, HRVBaseline.isValid(sdnnMs: sdnn) else {
            return HRVFactor(score: nil, calibration: calibration, nights: selection)
        }
        let factor = PartialFactor(factor: .hrv, score: HRVScorer.score(zScore: baseline.zScore(sdnnMs: sdnn)),
                                   todayValue: sdnn, baselineValue: baseline.typicalSDNNMs)
        return HRVFactor(score: factor, calibration: calibration, nights: selection)
    }

    /// Les nuits valides des 14 jours d'avant, sans celles qui ont moins de `HRVBaseline.minimumSamplesPerNight` mesures. S'il
    /// ne reste alors pas assez de nuits pour une ligne de base, toutes les nuits valides servent et aucune n'est écartée : une
    /// montre qui ne mesure qu'une fois par nuit garde sa VFC.
    func hrvNights(day: Date, history: [NightSample]) -> HRVNights {
        let window = nights(of: history, before: day, days: Self.hrvWindowDays)
            .filter { $0.sdnnMs.map(HRVBaseline.isValid(sdnnMs:)) == true }
        let wellSampled = window.filter { HRVBaseline.isWellSampled(sampleCount: $0.sdnnSampleCount) }
        guard wellSampled.count >= HRVBaseline.minimumNights else {
            return HRVNights(values: validSDNN(window), setAside: 0)
        }
        return HRVNights(values: validSDNN(wellSampled), setAside: window.count - wellSampled.count)
    }

    private func validSDNN(_ nights: [NightSample]) -> [Double] {
        nights.compactMap(\.sdnnMs).filter { HRVBaseline.isValid(sdnnMs: $0) }
    }

    // MARK: - FC de repos

    /// La référence est la moyenne des 7 jours d'avant, lue de la même façon que la valeur du jour : avec une FC la plus basse de
    /// la nuit, les nuits de même source ; s'il n'y en a pas assez (montre retirée, données d'avant la mise à jour), toutes.
    func restingHeartRateFactor(day: Date, today: NightSample, history: [NightSample]) -> PartialFactor? {
        guard let bpm = today.restingHeartRate else { return nil }
        let window = nights(of: history, before: day, days: Self.restingHeartRateWindowDays).filter { $0.restingHeartRate != nil }
        let sameSource = window.filter { $0.restingHeartRateSource == today.restingHeartRateSource }
        let reference = (sameSource.count >= Self.restingHeartRateMinimumValues ? sameSource : window).compactMap(\.restingHeartRate)
        guard reference.count >= Self.restingHeartRateMinimumValues else { return nil }
        let mean = reference.reduce(0, +) / Double(reference.count)
        return PartialFactor(factor: .restingHeartRate, score: RHRScorer.score(todayBpm: bpm, baselineMeanBpm: mean),
                             todayValue: bpm, baselineValue: mean)
    }

    // MARK: - Sommeil

    /// 70 % la dernière nuit (`SleepScorer`), 30 % la dette des 7 nuits (`SleepDebt`), la dernière comprise.
    func sleepFactor(day: Date, today: NightSample, history: [NightSample],
                     goalMinutes: Int) -> (score: PartialFactor?, debtMinutes: Int?) {
        guard let sleep = today.sleep else { return (nil, nil) }
        let lastNight = SleepScorer.score(asleepMinutes: sleep.asleepMinutes, deepMinutes: sleep.deepMinutes, targetMinutes: goalMinutes)
        let previous = nights(of: history, before: day, days: SleepDebt.windowNights - 1).compactMap { night -> SleepDebt.Night? in
            guard let asleep = night.sleep?.asleepMinutes, let age = offset(from: night, to: day) else { return nil }
            return SleepDebt.Night(age: age, asleepMinutes: asleep)
        }
        let debt = SleepDebt.minutes(nights: [SleepDebt.Night(age: 0, asleepMinutes: sleep.asleepMinutes)] + previous,
                                     goalMinutes: goalMinutes)
        let debtScore = SleepDebt.score(debtMinutes: debt, goalMinutes: goalMinutes)
        let score = SleepDebt.sleepFactor(lastNightScore: lastNight, debtScore: debtScore)
        return (PartialFactor(factor: .sleep, score: score, todayValue: Double(sleep.asleepMinutes), baselineValue: nil), debt)
    }
}
