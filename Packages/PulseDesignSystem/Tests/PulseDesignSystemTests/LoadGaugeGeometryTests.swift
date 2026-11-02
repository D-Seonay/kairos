import Testing

@testable import PulseDesignSystem

@Test func loadFractions() {
    let expected: [(ratio: Double, fraction: Double)] = [
        (0, 0), (0.8, 0.2), (1.12, 0.456), (1.3, 0.6), (1.5, 0.78), (2, 1), (3, 1), (-1, 0)
    ]
    for (ratio, fraction) in expected {
        #expect(abs(LoadGaugeGeometry.fraction(ratio: ratio) - fraction) < 1e-9)
    }
}

@Test func nonFiniteLoadRatioFallsBackToTheStart() {
    #expect(LoadGaugeGeometry.fraction(ratio: .nan) == 0)
    #expect(LoadGaugeGeometry.fraction(ratio: .infinity) == 1)
}

@Test func loadZonesFollowTheMockupGradient() {
    #expect(LoadGaugeGeometry.zoneBounds == [0, 0.2, 0.6, 0.78, 1])
}
