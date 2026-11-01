import Foundation
import PulseDomain
import PulseRecoveryEngine

/// La ligne de base montrée à l'écran de calibration : VFC sur 14 jours, FC de repos sur 7 jours, sommeil moyen.
public struct BaselineSummary: Sendable, Equatable {
    public var hrvMeanMs: Double?
    public var hrvDeviationMs: Double?
    public var restingHeartRateMean: Double?
    public var restingHeartRateDeviation: Double?
    public var sleepMeanMinutes: Int?
    public var nightsAnalyzed: Int

    public init(hrvMeanMs: Double?, hrvDeviationMs: Double?, restingHeartRateMean: Double?, restingHeartRateDeviation: Double?,
                sleepMeanMinutes: Int?, nightsAnalyzed: Int) {
        self.hrvMeanMs = hrvMeanMs
        self.hrvDeviationMs = hrvDeviationMs
        self.restingHeartRateMean = restingHeartRateMean
        self.restingHeartRateDeviation = restingHeartRateDeviation
        self.sleepMeanMinutes = sleepMeanMinutes
        self.nightsAnalyzed = nightsAnalyzed
    }

    private static let hrvWindowDays = 14
    private static let heartRateWindowDays = 7
    private static let sleepWindowDays = 14

    /// Les fenêtres comptent les jours qui précèdent `day` : la nuit de `day` lui-même n'y est jamais.
    public static func make(nights: [NightSample], day: Date, calendar: Calendar) -> BaselineSummary {
        let today = calendar.startOfDay(for: day)
        func within(_ days: Int) -> [NightSample] {
            nights.filter { night in
                let age = calendar.dateComponents([.day], from: calendar.startOfDay(for: night.day), to: today).day ?? 0
                return (1...days).contains(age)
            }
        }
        let hrv = statistics(within(hrvWindowDays).compactMap(\.sdnnMs).filter(HRVBaseline.isValid(sdnnMs:)))
        let heartRate = statistics(within(heartRateWindowDays).compactMap(\.restingHeartRate))
        let sleep = within(sleepWindowDays).compactMap { $0.sleep?.asleepMinutes }
        let analyzed = nights.filter { night in
            night.sdnnMs.map(HRVBaseline.isValid(sdnnMs:)) == true || night.restingHeartRate != nil || night.sleep != nil
        }
        return BaselineSummary(
            hrvMeanMs: hrv?.mean, hrvDeviationMs: hrv?.deviation,
            restingHeartRateMean: heartRate?.mean, restingHeartRateDeviation: heartRate?.deviation,
            sleepMeanMinutes: sleep.isEmpty ? nil : Int((Double(sleep.reduce(0, +)) / Double(sleep.count)).rounded()),
            nightsAnalyzed: analyzed.count
        )
    }

    /// Moyenne et écart-type d'échantillon ; `nil` sous deux valeurs.
    private static func statistics(_ values: [Double]) -> (mean: Double, deviation: Double)? {
        guard values.count >= 2 else { return nil }
        let count = Double(values.count)
        let mean = values.reduce(0, +) / count
        let variance = values.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / (count - 1)
        return (mean, variance.squareRoot())
    }
}
