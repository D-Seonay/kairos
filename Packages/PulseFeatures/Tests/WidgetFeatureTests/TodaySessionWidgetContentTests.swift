import Foundation
import PulseDomain
import Testing
@testable import WidgetFeature

struct TodaySessionWidgetContentTests {
    private let calendar = WidgetClock.calendar
    private let now = WidgetClock.date("2026-11-02T09:00")

    @Test func sessionSnapshotBuildsValidContent() {
        let snapshot = WidgetSample.snapshot(sessionTitle: "Push", isLightened: true)
        let content = TodaySessionWidgetContent.make(snapshot: snapshot, at: now, calendar: calendar)

        #expect(content.title == "Push")
        #expect(content.isAdjusted)
        #expect(content.isLightened)
        #expect(!content.isRest)
        #expect(content.buttonText == "Démarrer")
        #expect(content.accessoryTitle == "Push")
        #expect(content.accessorySubtitle == "14 séries · allégée")
        #expect(!content.muscleLevels.isEmpty)
    }

    @Test func restDayShowsRestContent() {
        let snapshot = WidgetSample.snapshot(sessionTitle: nil, isLightened: false)
        let content = TodaySessionWidgetContent.make(snapshot: snapshot, at: now, calendar: calendar)

        #expect(content.isRest)
        #expect(content.title == "Jour de repos")
        #expect(content.muscleLevels.isEmpty)
        #expect(content.accessorySubtitle == "Récupération active")
    }

    @Test func galleryLabels() {
        #expect(TodaySessionWidgetContent.kind == "TodaySessionWidget")
        #expect(TodaySessionWidgetContent.displayName == "Séance du jour")
        #expect(TodaySessionWidgetContent.summary == "Ta séance prévue, ses muscles ciblés et son volume.")
    }
}
