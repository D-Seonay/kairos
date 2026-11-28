import Foundation
@testable import PulseDomain
import Testing

@Test func nightSignalsAreReadInOrder() {
    #expect(NightSignal.allCases.map(\.kind) == [.sdnn, .restingHeartRate, .sleep, .heartRate])
}

/// La fréquence cardiaque brute, écrite plusieurs fois par heure, ne réveille pas l'app et n'est gardée que quelques jours.
@Test func rawHeartRateIsNotObservedAndKeptBriefly() {
    #expect(NightSignal.observed == [.sdnn, .restingHeartRate, .sleep])
    #expect(healthCacheRetention(for: .heartRate) == Double(NightSignal.heartRateHistoryDays + 2) * 86_400)
    #expect(healthCacheRetention(for: .heartRate) < healthCacheRetention(for: .restingHeartRate))
}

@Test func appLinkRoundTrips() throws {
    #expect(AppLink.today.url?.absoluteString == "fr.seonay.pulse://today")
    let url = try #require(URL(string: "fr.seonay.pulse://today"))
    #expect(AppLink(url: url) == .today)
    let other = try #require(URL(string: "https://x"))
    #expect(AppLink(url: other) == nil)
}

@Test func appLinksOfTheWidgetsAndControlsRoundTrip() throws {
    #expect(AppLink.planning.url?.absoluteString == "fr.seonay.pulse://planning")
    #expect(AppLink.startSession.url?.absoluteString == "fr.seonay.pulse://start-session")
    #expect(AppLink.why.url?.absoluteString == "fr.seonay.pulse://why")
    #expect(AppLink.run.url?.absoluteString == "fr.seonay.pulse://run")
    #expect(AppLink.bodyPhotos.url?.absoluteString == "fr.seonay.pulse://body-photos")
    #expect(AppLink.night.url?.absoluteString == "fr.seonay.pulse://night")
    for link in [AppLink.today, .supplements, .planning, .startSession, .why, .run, .bodyPhotos, .night] {
        let url = try #require(link.url)
        #expect(AppLink(url: url) == link)
    }
}
