import Foundation
@testable import PulseDomain
import Testing

@Test func nightSignalsAreReadInOrder() {
    #expect(NightSignal.allCases.map(\.kind) == [.sdnn, .restingHeartRate, .sleep])
}

@Test func appLinkRoundTrips() throws {
    #expect(AppLink.today.url?.absoluteString == "fr.seonay.pulse://today")
    let url = try #require(URL(string: "fr.seonay.pulse://today"))
    #expect(AppLink(url: url) == .today)
    let other = try #require(URL(string: "https://x"))
    #expect(AppLink(url: other) == nil)
}
