import Foundation
@testable import PulseDomain
import Testing

@Suite("Types de course du domaine")
struct RunTypesTests {
    @Test("la progression vers l'objectif suit les minutes ou les kilomètres")
    func targetProgressFollowsMinutesOrKilometres() {
        let timed = RunLaunch(title: "Footing", targetMinutes: 30)
        #expect(timed.targetProgress(movingSeconds: 900, distanceMeters: nil) == 0.5)

        let distance = RunLaunch(title: "Sortie", targetKm: 5)
        #expect(distance.targetProgress(movingSeconds: 600, distanceMeters: 4_000) == 0.8)
        #expect(distance.targetProgress(movingSeconds: 600, distanceMeters: nil) == nil)

        let free = RunLaunch(title: "Libre")
        #expect(free.targetProgress(movingSeconds: 900, distanceMeters: 4_000) == nil)
    }

    @Test("la progression n'est pas bornée à 1, l'objectif atteint se détecte à 1 ou plus")
    func targetProgressIsNotClamped() {
        let launch = RunLaunch(title: "Footing", targetMinutes: 30)
        #expect(launch.targetProgress(movingSeconds: 1_800, distanceMeters: nil) == 1)
        #expect(launch.targetProgress(movingSeconds: 2_700, distanceMeters: nil) == 1.5)
    }

    @Test("le brouillon survit à un aller-retour JSON")
    func draftRoundTripsThroughJSON() throws {
        let start = Date(timeIntervalSince1970: 1_000)
        let draft = RunDraft(
            sessionID: UUID(),
            launch: RunLaunch(title: "Footing", programID: UUID(), routineDayID: UUID(), runType: .easy,
                              targetMinutes: 30, targetKm: nil, adjustmentNote: "Allure facile"),
            startedAt: start,
            pauses: [RunPause(start: start.addingTimeInterval(300), end: start.addingTimeInterval(360)),
                     RunPause(start: start.addingTimeInterval(600), end: nil)],
            points: [
                RunTrackPoint(timestamp: start, latitude: 48.85, longitude: 2.35, altitude: 35,
                              horizontalAccuracy: 5, verticalAccuracy: 3),
                RunTrackPoint(timestamp: start.addingTimeInterval(5), latitude: 48.8501, longitude: 2.3501,
                              altitude: nil, horizontalAccuracy: 8, verticalAccuracy: nil)
            ],
            heartRates: [120, 124],
            locationDenied: false,
            updatedAt: start.addingTimeInterval(10)
        )
        let data = try JSONEncoder().encode(draft)
        #expect(try JSONDecoder().decode(RunDraft.self, from: data) == draft)
    }
}
