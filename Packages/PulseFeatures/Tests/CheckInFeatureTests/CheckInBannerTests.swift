@testable import CheckInFeature
import Testing

/// La bannière du check-in : elle ne parle de montre qu'à quelqu'un dont Pulse a déjà demandé l'accès à Apple Santé.
struct CheckInBannerTests {
    @Test func theBannerAsksAboutTheWatchOnceHealthAccessWasRequested() {
        let banner = CheckInText.banner(healthRequested: true)
        #expect(banner.title == "Pas de données de nuit")
        #expect(banner.message == "Montre déchargée ou non portée ? Trois questions suffisent pour estimer ta récupération.")
    }

    @Test func theBannerOffersHealthWhenAccessWasNeverRequested() {
        let banner = CheckInText.banner(healthRequested: false)
        #expect(banner.title == "Apple Santé n'est pas connecté")
        #expect(!banner.message.contains("Montre"))
        #expect(banner.message.contains("Trois questions suffisent"))
    }
}
