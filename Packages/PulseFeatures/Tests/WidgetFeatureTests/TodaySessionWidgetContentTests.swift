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
        #expect(content.accessorySubtitle == "allégée", "Sans détail dans l'instantané, pas de chiffres inventés")
        #expect(content.inlineText == "Push")
        #expect(!content.muscleLevels.isEmpty)
    }

    @Test func theSessionDetailComesFromTheSnapshot() {
        var snapshot = WidgetSample.snapshot(sessionTitle: "Push", isLightened: false)
        snapshot.sessionDetail = "5 exercices · 16 séries"
        let content = TodaySessionWidgetContent.make(snapshot: snapshot, at: now, calendar: calendar)
        #expect(content.metaText == "5 exercices · 16 séries · comme prévu")
        #expect(content.inlineText == "Push · 5 exercices · 16 séries")
        #expect(!content.isAdjusted)
    }

    @Test func contentFollowsTheSnapshotFigure() {
        var snapshot = WidgetSample.snapshot(sessionTitle: "Push", isLightened: false)
        snapshot.muscleMapFigure = .male
        #expect(TodaySessionWidgetContent.make(snapshot: snapshot, at: now, calendar: calendar).muscleMapFigure == .male)
        snapshot.muscleMapFigure = nil
        #expect(TodaySessionWidgetContent.make(snapshot: snapshot, at: now, calendar: calendar).muscleMapFigure == .female)
    }

    @Test func restDayShowsRestContent() {
        let snapshot = WidgetSample.snapshot(sessionTitle: nil, isLightened: false)
        let content = TodaySessionWidgetContent.make(snapshot: snapshot, at: now, calendar: calendar)

        #expect(content.isRest)
        #expect(content.title == "Jour de repos")
        #expect(content.muscleLevels.isEmpty)
        #expect(content.accessorySubtitle == "Récupération active")
        #expect(content.inlineText == "Jour de repos")
    }

    @Test func galleryLabels() {
        #expect(TodaySessionWidgetContent.kind == "TodaySessionWidget")
        #expect(TodaySessionWidgetContent.displayName == "Séance du jour")
        #expect(TodaySessionWidgetContent.summary == "Ta séance prévue, ses muscles ciblés et son volume.")
    }
}
