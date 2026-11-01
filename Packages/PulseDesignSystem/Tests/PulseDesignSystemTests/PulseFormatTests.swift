import Testing

@testable import PulseDesignSystem

@Test func durations() {
    #expect(PulseFormat.duration(minutes: 310) == "5 h 10")
    #expect(PulseFormat.duration(minutes: 425) == "7 h 05")
    #expect(PulseFormat.duration(minutes: 480) == "8 h")
    #expect(PulseFormat.duration(minutes: 45) == "45 min")
}

@Test func signedValues() {
    #expect(PulseFormat.signedPercent(-18.4) == "\u{2212}18 %")
    #expect(PulseFormat.signedPercent(3) == "+3 %")
    #expect(PulseFormat.signedPercent(0.2) == "0 %")
    #expect(PulseFormat.signedInteger(5, unit: "bpm") == "+5 bpm")
    #expect(PulseFormat.signedInteger(-3.4, unit: "bpm") == "\u{2212}3 bpm")
    #expect(PulseFormat.integer(44.4, unit: "ms") == "44 ms")
}

@Test func negativeValuesThatRoundToZeroHaveNoSign() {
    #expect(PulseFormat.signedPercent(-0.2) == "0 %")
    #expect(PulseFormat.signedInteger(-0.4, unit: "bpm") == "0 bpm")
}

@Test func integerWithoutUnit() {
    #expect(PulseFormat.integer(61.6, unit: nil) == "62")
}

@Test func nonFiniteValuesNeverCrashAndShowADash() {
    for value in [Double.nan, .infinity, -.infinity] {
        #expect(PulseFormat.integer(value, unit: "ms") == "\u{2014}")
        #expect(PulseFormat.integer(value, unit: nil) == "\u{2014}")
        #expect(PulseFormat.signedPercent(value) == "\u{2014}")
        #expect(PulseFormat.signedInteger(value, unit: "bpm") == "\u{2014}")
    }
}

@Test func outOfRangeValuesShowADash() {
    #expect(PulseFormat.integer(1e30, unit: "ms") == "\u{2014}")
    #expect(PulseFormat.signedInteger(-1e30, unit: "bpm") == "\u{2014}")
}
