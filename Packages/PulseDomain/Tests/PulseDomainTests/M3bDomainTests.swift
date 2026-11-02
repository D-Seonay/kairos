@testable import PulseDomain
import Testing

@Test func nightSignalsAreReadInOrder() {
    #expect(NightSignal.allCases.map(\.kind) == [.sdnn, .restingHeartRate, .sleep])
}
