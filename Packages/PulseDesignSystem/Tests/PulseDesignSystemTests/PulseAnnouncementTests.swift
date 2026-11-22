import Testing

@testable import PulseDesignSystem

@Test func announcesOnlyANewNonEmptyMessage() {
    #expect(PulseAnnouncement.shouldAnnounce(from: nil, to: "Erreur") == true)
    #expect(PulseAnnouncement.shouldAnnounce(from: "Erreur", to: "Autre erreur") == true)
    #expect(PulseAnnouncement.shouldAnnounce(from: "Erreur", to: "Erreur") == false)
    #expect(PulseAnnouncement.shouldAnnounce(from: "Erreur", to: nil) == false)
    #expect(PulseAnnouncement.shouldAnnounce(from: nil, to: "") == false)
}

@Test func announcesOncePerIdentifier() {
    let seen: Set<AnyHashable> = [AnyHashable(1)]
    #expect(PulseAnnouncement.shouldAnnounce("Repos terminé", id: AnyHashable(1), announced: seen) == false)
    #expect(PulseAnnouncement.shouldAnnounce("Repos terminé", id: AnyHashable(2), announced: seen) == true)
    #expect(PulseAnnouncement.shouldAnnounce(nil, id: AnyHashable(2), announced: seen) == false)
}
