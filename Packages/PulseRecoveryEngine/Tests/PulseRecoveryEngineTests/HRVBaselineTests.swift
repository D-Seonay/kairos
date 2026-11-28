import Foundation
@testable import PulseRecoveryEngine
import Testing

@Test func baselineNeedsFiveNights() {
    #expect(HRVBaseline(sdnnValuesMs: [50, 50, 50, 50]) == nil)
    #expect(HRVBaseline(sdnnValuesMs: [50, 50, 50, 50, 50]) != nil)
}

@Test func baselineUsesMedianAndScaledMADOnLogValues() throws {
    // ln des valeurs = 1, 2, 3, 4, 5 → médiane 3, écarts 2, 1, 0, 1, 2 → MAD 1, × 1,4826
    let values = [1.0, 2.0, 3.0, 4.0, 5.0].map { exp($0) }
    let baseline = try #require(HRVBaseline(sdnnValuesMs: values))
    #expect(abs(baseline.center - 3.0) < 1e-9)
    #expect(abs(baseline.spread - 1.4826) < 1e-9)
    #expect(baseline.nights == 5)
    #expect(abs(baseline.typicalSDNNMs - exp(3.0)) < 1e-9)
}

@Test func baselineMedianOfAnEvenCountIsTheMiddlePair() throws {
    let values = [1.0, 2.0, 3.0, 4.0, 5.0, 5.5].map { exp($0) } // exp(6) dépasserait 300 ms
    let baseline = try #require(HRVBaseline(sdnnValuesMs: values))
    #expect(abs(baseline.center - 3.5) < 1e-9)
}

@Test func baselineFloorsTheSpread() throws {
    let baseline = try #require(HRVBaseline(sdnnValuesMs: Array(repeating: 50, count: 14)))
    #expect(baseline.spread == 0.05)
    #expect(baseline.zScore(sdnnMs: 50) == 0)
}

@Test func baselineIgnoresOutOfRangeValues() {
    #expect(HRVBaseline(sdnnValuesMs: [0, -5, 400, 50, 50, 50, 50]) == nil) // 4 valides
    #expect(HRVBaseline(sdnnValuesMs: [0, 400, 50, 50, 50, 50, 50])?.nights == 5)
}

/// Une nuit aberrante parmi six : la médiane et le MAD ne bougent presque pas, là où une moyenne aurait glissé de 20 %.
@Test func oneOutlierNightBarelyMovesTheBaseline() throws {
    let steady: [Double] = [48, 50, 52, 49, 51, 50]
    let withOutlier = steady + [15]
    let clean = try #require(HRVBaseline(sdnnValuesMs: steady))
    let noisy = try #require(HRVBaseline(sdnnValuesMs: withOutlier))
    #expect(abs(noisy.typicalSDNNMs - clean.typicalSDNNMs) < 1)
    #expect(abs(noisy.zScore(sdnnMs: 45) - clean.zScore(sdnnMs: 45)) < 0.6)
    #expect(noisy.zScore(sdnnMs: 45) < -1, "Une baisse de 10 % reste visible malgré la nuit aberrante")
}

@Test func aNightNeedsTwoSamplesToBeWellSampled() {
    #expect(HRVBaseline.isWellSampled(sampleCount: 1) == false)
    #expect(HRVBaseline.isWellSampled(sampleCount: 2))
    #expect(HRVBaseline.isWellSampled(sampleCount: nil), "Un nombre inconnu (fixtures, anciennes données) passe")
}
