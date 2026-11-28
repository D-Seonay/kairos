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

    /// La FC de repos qui compte et d'où elle vient.
    struct RestingHeartRateFactor {
        var score: PartialFactor
        var source: RestingHeartRateSource?
    }

    /// La référence est la moyenne des 7 jours d'avant, toujours lue à la même source que la valeur du jour : un minimum nocturne
    /// face aux minima nocturnes, un échantillon Apple face aux échantillons Apple des mêmes nuits (gardés même quand la nuit a son
    /// minimum). Une nuit « FC la plus basse » sans assez de nuits de même source se compare par son échantillon Apple ; sans
    /// `restingHeartRateMinimumValues` valeurs comparables, pas de facteur : mieux vaut un facteur absent qu'un écart de source.
    func restingHeartRateFactor(day: Date, today: NightSample, history: [NightSample]) -> RestingHeartRateFactor? {
        let window = nights(of: history, before: day, days: Self.restingHeartRateWindowDays)
        var sources: [RestingHeartRateSource?] = [today.restingHeartRateSource]
        if today.restingHeartRateSource == .overnightLowest { sources.append(.appleNearWake) }
        for source in sources {
            guard let bpm = Self.restingHeartRate(of: today, from: source) else { continue }
            let reference = window.compactMap { Self.restingHeartRate(of: $0, from: source) }
            guard reference.count >= Self.restingHeartRateMinimumValues else { continue }
            let mean = reference.reduce(0, +) / Double(reference.count)
            let factor = PartialFactor(factor: .restingHeartRate, score: RHRScorer.score(todayBpm: bpm, baselineMeanBpm: mean),
                                       todayValue: bpm, baselineValue: mean)
            return RestingHeartRateFactor(score: factor, source: source)
        }
        return nil
    }

    /// La FC de repos de la nuit lue à `source` ; sans source connue (fixtures), celle des nuits sans source.
    private static func restingHeartRate(of night: NightSample, from source: RestingHeartRateSource?) -> Double? {
        switch source {
        case .overnightLowest:
            night.restingHeartRateSource == .overnightLowest ? night.restingHeartRate : nil
        case .appleNearWake:
            night.appleRestingHeartRate ?? (night.restingHeartRateSource == .appleNearWake ? night.restingHeartRate : nil)
        case nil:
            night.restingHeartRateSource == nil ? night.restingHeartRate : nil
        }
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
