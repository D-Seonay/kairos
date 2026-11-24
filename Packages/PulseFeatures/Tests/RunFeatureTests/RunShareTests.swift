import Foundation
import PulseDesignSystem
@testable import RunFeature
import Testing

private let paris: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Paris") ?? .gmt
    calendar.locale = Locale(identifier: "fr_FR")
    return calendar
}()

private let sunday = ISO8601DateFormatter().date(from: "2026-11-22T09:00:00+01:00") ?? .distantPast

@Test func runShareCardShowsDistanceTimePaceAndTheRoute() {
    let card = RunRecapModel.shareContent(
        title: "Footing", date: sunday, movingSeconds: 2_770, distanceMeters: 8_420, averagePace: 329, elevationGain: 42,
        averageHeartRate: 151, latitudes: [48.85, 48.86, 48.87], longitudes: [2.35, 2.36, 2.35], calendar: paris)
    #expect(card.eyebrow == "Course")
    #expect(card.title == "Footing")
    #expect(card.subtitle == "dimanche 22 novembre")
    #expect(card.metrics.map(\.label) == ["Distance", "En mouvement", "Allure", "Dénivelé"])
    #expect(card.metrics.map(\.value) == ["8,42 km", "46:10", "5'29\"/km", "+42 m"])
    guard case .route(let points) = card.visual else {
        Issue.record("La carte d'une course avec un tracé le dessine.")
        return
    }
    #expect(points.count == 3)
}

@Test func runShareCardWithoutLocationKeepsTheTimeAndTheHeartRate() {
    let card = RunRecapModel.shareContent(
        title: "", date: sunday, movingSeconds: 1_800, distanceMeters: nil, averagePace: nil, elevationGain: nil,
        averageHeartRate: 148, latitudes: [], longitudes: [], calendar: paris)
    #expect(card.title == "Course")
    #expect(card.metrics.map(\.label) == ["En mouvement", "FC moyenne"])
    #expect(card.visual == .none)
}
