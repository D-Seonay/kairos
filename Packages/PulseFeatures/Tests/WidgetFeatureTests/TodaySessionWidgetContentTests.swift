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

    /// Sans instantané du jour, le widget ne montre pas la séance d'exemple comme si elle était prévue.
    @Test func missingOrStaleSnapshotIsNotReady() {
        let stale = WidgetSample.snapshot(sessionTitle: "Push", isLightened: true)
        let yesterday = TodaySessionWidgetContent.make(snapshot: stale, at: WidgetClock.date("2026-11-03T09:00"), calendar: calendar)
        let missing = TodaySessionWidgetContent.make(snapshot: nil, at: now, calendar: calendar)
        #expect(yesterday == missing)
        #expect(missing != .sample(at: now, calendar: calendar))
        #expect(!missing.isReady && !missing.isAdjusted && !missing.isRest)
        #expect(missing.title == "Séance pas encore prête")
        #expect(missing.muscleLevels.isEmpty)
        #expect(missing.accessibilityLabel == "Séance du jour pas encore prête. Ouvre Pulse pour la charger")
        #expect(TodaySessionWidgetContent.make(snapshot: stale, at: now, calendar: calendar).isReady)
    }

    @Test func galleryLabels() {
        #expect(TodaySessionWidgetContent.kind == "TodaySessionWidget")
        #expect(TodaySessionWidgetContent.displayName == "Séance du jour")
        #expect(TodaySessionWidgetContent.summary == "Ta séance prévue, ses muscles ciblés et son volume.")
    }
}
