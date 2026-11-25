import Foundation
import PulseDomain
import PulseServices
import Testing

/// L'ambiance des widgets suit le profil à chaque passage du jour : celle choisie avant cette version arrive aux widgets sans
/// retoucher le réglage.
struct DayRefresherWidgetThemeTests {
    @Test func refreshSharesTheProfileThemeWithTheWidgets() async throws {
        let fixture = RefresherFixture(scenario: .goodNight)
        try await fixture.adopt()
        var profile = try #require(try await fixture.profiles.load())
        profile.theme = .amethyst
        try await fixture.profiles.save(profile)

        _ = await fixture.refresher.refresh(origin: .foreground)

        #expect(await fixture.widgets.publishedThemes == [.amethyst])
    }

    @Test func withoutAProfileNoThemeIsShared() async throws {
        let fixture = RefresherFixture(scenario: .goodNight)
        _ = await fixture.refresher.refresh(origin: .foreground)
        #expect(await fixture.widgets.publishedThemes.isEmpty)
    }
}
