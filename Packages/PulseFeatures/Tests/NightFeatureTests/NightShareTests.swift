import Foundation
@testable import NightFeature
import PulseDesignSystem
import PulseDomain
import Testing

@Test func nightShareCardDrawsTheHypnogramWithStageMinutes() {
    var night = NightFixtures.typicalNight()
    let fell = night.fellAsleep, mid = fell.addingTimeInterval(4 * 3_600)
    night.segments = [SleepSegment(start: fell, end: mid, stage: .core),
                      SleepSegment(start: mid, end: night.wokeUp, stage: .deep),
                      SleepSegment(start: night.wokeUp, end: night.wokeUp.addingTimeInterval(600), stage: .awake)]
    let card = NightModel.shareContent(of: night, calendar: NightFixtures.calendar)
    #expect(card.eyebrow == "Nuit")
    #expect(card.title == "Nuit du 19 au 20 nov.")
    #expect(card.subtitle.hasPrefix("Endormi à 23:10"))
    #expect(card.metrics.map(\.label) == ["Endormi", "Profond", "Paradoxal", "Léger"])
    #expect(card.metrics.map(\.value) == ["7 h 30", "1 h 30", "1 h", "5 h"])
    guard case .hypnogram(let hypnogram) = card.visual else {
        Issue.record("Une nuit avec des phases dessine son hypnogramme.")
        return
    }
    #expect(hypnogram.rows == ["Éveil", "Paradoxal", "Léger", "Profond"])
    // La tranche d'éveil après le réveil sort de la nuit : elle est écartée.
    #expect(hypnogram.bars.map(\.row) == [2, 3])
    #expect(hypnogram.bars.first?.start == 0)
    #expect(hypnogram.bars.last?.end == 1)
}

@Test func nightShareCardWithoutStagesShowsTheTimeAsleepInLarge() {
    let card = NightModel.shareContent(of: NightFixtures.typicalNight(awakenings: 2, hasStages: false),
                                       calendar: NightFixtures.calendar)
    #expect(card.visual == .hero(value: "7 h 30", label: "Temps endormi"))
    #expect(card.metrics.map(\.caption) == ["2 réveils"])
}
