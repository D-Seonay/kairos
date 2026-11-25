import Foundation
import PulseDesignSystem
import PulseDomain
import PulseServices
@testable import StatsFeature
import Testing

private let paris: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Paris") ?? .gmt
    calendar.locale = Locale(identifier: "fr_FR")
    return calendar
}()

private let tuesday = paris.date(from: DateComponents(year: 2026, month: 11, day: 24, hour: 18)) ?? .distantPast

@Test func strengthRecordCardPutsTheEstimateInLargeWithItsSetAndGain() {
    let line = StrengthRecordLine(exercise: .content(id: "bench-press-barbell"), name: "Développé couché", kind: .estimatedOneRepMax,
                                  value: 95.6, weightKg: 85, reps: 5, date: tuesday, gain: 2.5, isNew: false)
    let card = RecordShareCard.strength(line, calendar: paris)
    #expect(card.eyebrow == "Record")
    #expect(card.title == "Développé couché")
    #expect(card.subtitle == "mardi 24 novembre")
    #expect(card.visual == .hero(value: "95,6 kg", label: "1RM estimé"))
    #expect(card.metrics.map(\.value) == ["85 × 5", "+2,5 kg"])
    #expect(card.caption.hasPrefix("Développé couché · 95,6 kg · 85 kg × 5 · +2,5 kg\n"))
}

@Test func bodyweightRecordCardCountsRepetitions() {
    let line = StrengthRecordLine(exercise: .content(id: "pull-up"), name: "Tractions", kind: .repsAtWeight, value: 14,
                                  weightKg: nil, reps: 14, date: tuesday, gain: nil, isNew: true)
    let card = RecordShareCard.strength(line, calendar: paris)
    #expect(card.visual == .hero(value: "14 reps", label: "Répétitions"))
    #expect(card.metrics.isEmpty)
}

@Test func runRecordCardShowsTheBestTimeAndItsPace() throws {
    let card = try #require(RecordShareCard.run(RunBest(distance: .fiveK, seconds: 1_453, date: tuesday, isNew: true),
                                                calendar: paris))
    #expect(card.title == "5 km")
    #expect(card.visual == .hero(value: "24:13", label: "Meilleur temps"))
    #expect(card.metrics.map(\.value) == ["4'51\"/km"])
    #expect(RecordShareCard.run(RunBest(distance: .half, seconds: nil, date: nil, isNew: false), calendar: paris) == nil)
}
