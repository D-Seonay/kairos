import Foundation
@testable import LiveSessionFeature
import PulseDesignSystem
import PulseDomain
import PulseServices
import Testing

@MainActor @Test func recapShareCardShowsTheSessionWithItsMusclesOnceLoaded() async throws {
    let fixture = LiveFixture()
    try await fixture.seedBenchHistory()
    let live = try await fixture.startedModel()
    for set in live.session.exercises[0].sets { await live.tap(set: set.id) }
    fixture.clock.set("2026-11-02T09:00")
    let model = RecapModel(service: fixture.service, endedAt: fixture.environment.now())
    #expect(model.shareContent(calendar: fixture.environment.calendar) == nil)

    await model.load()
    let recap = try #require(model.recap)
    let card = try #require(model.shareContent(calendar: fixture.environment.calendar))
    #expect(card.eyebrow == "Séance")
    #expect(card.title == (recap.title.isEmpty ? "Séance" : recap.title))
    #expect(card.subtitle == "lundi 2 novembre")
    #expect(card.metrics.first?.label == "Durée")
    #expect(card.metrics.contains { $0.label == "Séries" && $0.value == "\(recap.workingSets)" })
    guard case .muscles(let levels) = card.visual else {
        Issue.record("La carte d'une séance montre ses muscles.")
        return
    }
    #expect(levels == MuscleIntensity.levels(weights: recap.muscleWeights))
    #expect(card.highlights.allSatisfy { !$0.contains("nouveau record") })
}

@Test func recapShareCardCountsTonnageAndRecords() {
    let records = [
        BeatenRecord(exerciseName: "Développé couché", kind: .maxWeight, text: "Développé couché : 82,5 kg, nouveau record de charge"),
        BeatenRecord(exerciseName: "Développé couché", kind: .estimatedOneRepMax,
                     text: "Développé couché : 1RM estimé 95 kg, nouveau record"),
        BeatenRecord(exerciseName: "Dips", kind: .repsAtWeight, text: "Dips : 12 répétitions au poids du corps, nouveau record")
    ]
    #expect(RecapModel.recordHeadlines(records) == ["Développé couché : 82,5 kg", "Dips : 12 répétitions au poids du corps"])
    #expect(RecapModel.recordsCaption(1) == "1 record")
    #expect(RecapModel.recordsCaption(3) == "3 records")
}

@Test func beatenRecordHeadlineKeepsATextWithoutTheRecordClause() {
    let record = BeatenRecord(exerciseName: "Squat", kind: .maxWeight, text: "Squat : 120 kg")
    #expect(record.headline == "Squat : 120 kg")
}
