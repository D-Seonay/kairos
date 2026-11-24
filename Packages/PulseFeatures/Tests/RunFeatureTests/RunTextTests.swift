import Foundation
import PulseDesignSystem
import PulseDomain
import PulseServices
@testable import RunFeature
import Testing

struct RunTextTests {
    @Test func kilometerSentenceUsesSpokenUnits() {
        let expected = """
            \(PulseSpoken.count(3, singular: "kilomètre", plural: "kilomètres")). \(PulseSpoken.duration(seconds: 1000)). \
            Allure \(PulseSpoken.pace(secondsPerKilometer: 332)).
            """
        let text = RunText.spokenText(for: .kilometer(3, movingSeconds: 1000, splitSeconds: 332))
        #expect(text == expected)
        #expect(text == "3 kilomètres. 16 minutes 40. Allure 5 minutes 32 par kilomètre.")
    }

    @Test func singleKilometreIsSingular() {
        let text = RunText.spokenText(for: .kilometer(1, movingSeconds: 330, splitSeconds: 330))
        #expect(text.hasPrefix("1 kilomètre. "))
    }

    @Test func targetMilestones() {
        #expect(RunText.spokenText(for: .halfTarget) == "Mi-objectif.")
        #expect(RunText.spokenText(for: .targetReached) == "Objectif atteint.")
    }

    @Test func splitIsSpokenInFull() {
        #expect(RunText.splitSpoken(RunSplit(kilometer: 3, seconds: 332, distanceMeters: 1_000))
            == "Kilomètre 3, 5 minutes 32 secondes")
        #expect(RunText.splitSpoken(RunSplit(kilometer: 5, seconds: 130.4, distanceMeters: 420))
            == "Kilomètre 5 partiel, 420 mètres, 2 minutes 10 secondes")
    }

    @Test func splitIsShownWithPace() {
        #expect(RunText.splitTime(332) == "5'32\"")
        #expect(RunText.pace(331) == "5'31\"/km")
        #expect(RunText.pace(nil) == "—")
    }

    @Test func routeLabelSaysTheDistance() {
        #expect(RunText.routeLabel(distanceMeters: 4_380) == "Tracé de la course, 4,4 kilomètres")
    }

    @Test func routeDistanceAddsSegments() {
        let start = RunFeatureFixture.start
        let points = (0...10).map { step in
            RunTrackPoint(timestamp: start.addingTimeInterval(Double(step)), latitude: 48.8566 + Double(step) * 100 / 111_195,
                          longitude: 2.3522, horizontalAccuracy: 5)
        }
        #expect(abs(RunText.routeDistance(points) - 1_000) < 5)
        #expect(RunText.routeDistance([]) == 0)
    }

    @Test func elapsedTimeIsAClock() {
        #expect(RunText.elapsed(seconds: 1_453) == "24:13")
        #expect(RunText.elapsed(seconds: 3_725) == "1:02:05")
        #expect(RunText.elapsedSpoken(seconds: 1_453) == "24 minutes 13")
    }

    @Test func distanceIsShownInKilometres() {
        #expect(RunText.distance(4_380) == "4,38 km")
        #expect(RunText.distance(nil) == "—")
    }

    @Test func liveDistanceAlwaysKeepsTwoDecimals() {
        #expect(RunText.liveDistance(4_990) == "4,99 km")
        #expect(RunText.liveDistance(5_000) == "5,00 km")
        #expect(RunText.liveDistance(5_010) == "5,01 km")
        #expect(RunText.liveDistance(12_400) == "12,40 km")
        #expect(RunText.liveDistance(nil) == "—")
    }

    @Test func goalLine() {
        let timed = RunLaunch(title: "Footing facile", runType: .easy, targetMinutes: 30)
        #expect(RunText.goalLine(timed) == "Footing facile · obj. 30 min")
        #expect(RunText.goalLine(RunLaunch(title: "Sortie longue", targetKm: 8.5)) == "Sortie longue · obj. 8,5 km")
        #expect(RunText.goalLine(RunLaunch(title: "Course libre")) == "Course libre")
    }

    @Test func passedKilometreIsAnnouncedOnce() {
        #expect(RunText.kilometerPassed(from: 950, to: 1_010) == "1 kilomètre")
        #expect(RunText.kilometerPassed(from: 1_010, to: 1_200) == nil)
        #expect(RunText.kilometerPassed(from: nil, to: 2_100) == nil)
    }

    @Test func recoveryMessageGivesDistanceAndTime() {
        let offer = RunRecoveryOffer(sessionID: UUID(), distanceMeters: 4_200,
                                     lastPointAt: RunTestClock.date("2026-11-24T07:52"), isStillRecording: false)
        #expect(RunText.recoveryMessage(offer, calendar: RunTestClock.calendar)
            == "Course interrompue : enregistrer 4,2 km jusqu'à 7 h 52 ?")
        let timeOnly = RunRecoveryOffer(sessionID: UUID(), distanceMeters: nil,
                                        lastPointAt: RunTestClock.date("2026-11-24T07:05"), isStillRecording: false)
        #expect(RunText.recoveryMessage(timeOnly, calendar: RunTestClock.calendar)
            == "Course interrompue : l'enregistrer jusqu'à 7 h 05 ?")
    }
}
