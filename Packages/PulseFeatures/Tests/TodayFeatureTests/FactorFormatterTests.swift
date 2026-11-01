import Foundation
import PulseDomain
import Testing
@testable import TodayFeature

struct FactorFormatterTests {
    private func recovery(asleep: Int? = 310, deep: Int? = 22, sdnn: Double? = 44, rhr: Double? = 54,
                          missing: [Factor] = [], calibration: CalibrationState = .ready,
                          isEstimated: Bool = false) -> DailyRecovery {
        let now = Date(timeIntervalSinceReferenceDate: 0)
        return DailyRecovery(
            day: now, score: 72, category: .normal, isEstimated: isEstimated, sdnnMs: sdnn, sdnnBaselineMs: sdnn.map { _ in 53.7 },
            restingHeartRate: rhr, restingHeartRateBaseline: rhr.map { _ in 49 }, asleepMinutes: asleep, deepMinutes: deep,
            missingFactors: missing, calibration: calibration, createdAt: now, updatedAt: now)
    }

    @Test func allFactorsPresent() {
        let displays = FactorFormatter.displays(for: recovery())
        #expect(displays.map(\.factor) == [.sleep, .hrv, .restingHeartRate])
        #expect(displays.map(\.title) == ["Sommeil", "Variabilité", "FC repos"])
        #expect(displays.map(\.value) == ["5 h 10", "44 ms", "54"])
        #expect(displays.map(\.detail) == ["profond 7 %", "\u{2212}18 % vs 14 j", "+5 bpm"])
        #expect(displays.allSatisfy { !$0.isMissing })
    }

    @Test func missingFactorReadsNoData() {
        let displays = FactorFormatter.displays(for: recovery(asleep: nil, deep: nil, missing: [.sleep]))
        let sleep = displays[0]
        #expect(sleep.value == "\u{2014}")
        #expect(sleep.detail == "pas de donnée cette nuit")
        #expect(sleep.isMissing)
        #expect(!displays[1].isMissing)
    }

    @Test func unknownDeepSleep() {
        let sleep = FactorFormatter.displays(for: recovery(deep: nil))[0]
        #expect(sleep.value == "5 h 10")
        #expect(sleep.detail == "phases inconnues")
        #expect(!sleep.isMissing)
    }

    @Test func hrvBaselineInProgress() {
        let hrv = FactorFormatter.displays(for: recovery(sdnn: nil, missing: [.hrv], calibration: .calibrating(nights: 3)))[1]
        #expect(hrv.value == "\u{2014}")
        #expect(hrv.detail == "ligne de base en cours, 3 sur 5 nuits")
        #expect(hrv.isMissing)
    }

    @Test func hrvMissingAfterBaselineReadsNoData() {
        let hrv = FactorFormatter.displays(for: recovery(sdnn: nil, missing: [.hrv], calibration: .ready))[1]
        #expect(hrv.detail == "pas de donnée cette nuit")
    }

    @Test func estimatedScoreHasNoMeasurement() {
        let displays = FactorFormatter.displays(for: recovery(
            asleep: nil, deep: nil, sdnn: nil, rhr: nil, missing: Factor.allCases, calibration: .calibrating(nights: 0),
            isEstimated: true))
        #expect(displays.allSatisfy { $0.isMissing })
    }

    @Test func markers() {
        #expect(FactorFormatter.marker(for: recovery(calibration: .calibrating(nights: 9))) == "En calibration (9 nuits)")
        #expect(FactorFormatter.marker(for: recovery(calibration: .ready)) == nil)
        #expect(FactorFormatter.marker(for: recovery(isEstimated: true)) == "Estimé")
        #expect(FactorFormatter.marker(for: recovery(sdnn: nil, missing: [.hrv], calibration: .calibrating(nights: 3))) == nil)
    }
}
