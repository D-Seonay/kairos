import Foundation
import Testing
@testable import PulseRecoveryEngine

@Test func baselineNeedsFiveNights() {
    #expect(HRVBaseline(sdnnValuesMs: [50, 50, 50, 50]) == nil)
    #expect(HRVBaseline(sdnnValuesMs: [50, 50, 50, 50, 50]) != nil)
}

@Test func baselineUsesSampleStandardDeviationOnLogValues() throws {
    // ln des valeurs = 1, 2, 3, 4, 5 → moyenne 3, sd échantillon √2,5
    let values = [1.0, 2.0, 3.0, 4.0, 5.0].map { exp($0) }
    let baseline = try #require(HRVBaseline(sdnnValuesMs: values))
    #expect(abs(baseline.mean - 3.0) < 1e-9)
    #expect(abs(baseline.standardDeviation - 2.5.squareRoot()) < 1e-9)
    #expect(baseline.nights == 5)
}

@Test func baselineFloorsStandardDeviation() throws {
    let baseline = try #require(HRVBaseline(sdnnValuesMs: Array(repeating: 50, count: 14)))
    #expect(baseline.standardDeviation == 0.05)
    #expect(baseline.zScore(sdnnMs: 50) == 0)
}

@Test func baselineIgnoresOutOfRangeValues() {
    #expect(HRVBaseline(sdnnValuesMs: [0, -5, 400, 50, 50, 50, 50]) == nil) // 4 valides
    #expect(HRVBaseline(sdnnValuesMs: [0, 400, 50, 50, 50, 50, 50])?.nights == 5)
}
