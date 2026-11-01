import CheckInFeature
import Foundation
import PulseDomain
import PulseServices
import Testing
@testable import TodayFeature

@MainActor
struct TodayModelTests {
    @Test func refreshScoresAndPlansMonday() async throws {
        let fixture = TodayFixture()
        let program = try await fixture.adopt("ppl-3")
        let model = fixture.makeModel()
        await model.refresh()
        guard case .scored(let recovery) = model.score else {
            Issue.record("Un score était attendu, obtenu \(String(describing: model.score))")
            return
        }
        #expect(recovery.category == .optimal)
        #expect(model.plannedDay == .strength(program.days[0]))
        #expect(program.days[0].name == "Push")
        #expect(model.summary?.setCount == 19)
        #expect(model.factors.count == 3)
        #expect(model.marker == nil)
        #expect(model.lastSync == TodayClock.date("2026-11-02T08:00"))
        #expect(model.lastSyncText == "08:00")
        #expect(!model.isLoading)
    }

    @Test func refreshWithoutProgramPlansNothing() async throws {
        let fixture = TodayFixture()
        try await fixture.profiles.save(UserProfile(createdAt: fixture.clock.now))
        let model = fixture.makeModel()
        await model.refresh()
        #expect(model.plannedDay == .noProgram)
        #expect(model.summary == nil)
    }

    @Test func restDayHasNoSummary() async throws {
        let fixture = TodayFixture(at: "2026-11-03T08:00")
        try await fixture.adopt("ppl-3")
        let model = fixture.makeModel()
        await model.refresh()
        guard case .rest(let next) = model.plannedDay else {
            Issue.record("Un repos était attendu, obtenu \(model.plannedDay)")
            return
        }
        #expect(next?.weekday == .wednesday)
        #expect(model.summary == nil)
    }

    @Test func greetingWithoutFirstName() async {
        let model = TodayFixture().makeModel()
        await model.refresh()
        #expect(model.greeting == "Bonjour")
    }

    @Test func greetingWithFirstName() async throws {
        let fixture = TodayFixture()
        try await fixture.adopt("ppl-3", firstName: "Mathéo")
        let model = fixture.makeModel()
        await model.refresh()
        #expect(model.greeting == "Bonjour Mathéo")
    }

    @Test func checkInFromToday() async throws {
        let fixture = TodayFixture(scenario: .threeNights)
        let model = fixture.makeModel()
        await model.refresh()
        guard case .needsCheckIn = model.score else {
            Issue.record("Un check-in était attendu, obtenu \(String(describing: model.score))")
            return
        }
        model.checkIn.selection = [.sleep: 3, .pain: 3, .motivation: 3]
        await model.submitCheckIn()
        guard case .scored(let recovery) = model.score else {
            Issue.record("Un score estimé était attendu, obtenu \(String(describing: model.score))")
            return
        }
        #expect(recovery.isEstimated)
        #expect(model.marker == "Estimé")
        #expect(model.factors.allSatisfy { $0.isMissing })
    }

    @Test func checkInIsIgnoredOverAScore() async throws {
        let fixture = TodayFixture()
        let model = fixture.makeModel()
        await model.refresh()
        let before = model.score
        model.checkIn.selection = [.sleep: 1, .pain: 1, .motivation: 1]
        await model.submitCheckIn()
        #expect(model.score == before)
    }

    @Test func incompleteCheckInChangesNothing() async {
        let fixture = TodayFixture(scenario: .threeNights)
        let model = fixture.makeModel()
        await model.refresh()
        model.checkIn.selection = [.sleep: 3]
        await model.submitCheckIn()
        guard case .needsCheckIn = model.score else {
            Issue.record("Le check-in devait rester à faire, obtenu \(String(describing: model.score))")
            return
        }
    }

    @Test func secondCheckInWhileOneIsInFlightIsIgnored() async {
        let fixture = TodayFixture(scenario: .threeNights)
        let model = fixture.makeModel()
        await model.refresh()
        model.checkIn.selection = [.sleep: 3, .pain: 3, .motivation: 3]
        async let first: Void = model.submitCheckIn()
        async let second: Void = model.submitCheckIn()
        _ = await (first, second)
        guard case .scored = model.score else {
            Issue.record("Un score était attendu, obtenu \(String(describing: model.score))")
            return
        }
    }

    @Test func concurrentRefreshesAreCoalesced() async {
        let fixture = TodayFixture()
        let model = fixture.makeModel()
        async let first: Void = model.refresh()
        async let second: Void = model.refresh()
        _ = await (first, second)
        #expect(!model.isLoading)
        guard case .scored = model.score else {
            Issue.record("Un score était attendu, obtenu \(String(describing: model.score))")
            return
        }
    }

    @Test func beforeDayStartKeepsYesterdayOnly() async {
        let fixture = TodayFixture(at: "2026-11-02T03:00")
        let model = fixture.makeModel()
        await model.refresh()
        #expect(model.score == .beforeDayStart(yesterday: nil))
        #expect(model.factors.isEmpty)
    }

    @Test func refreshWithFailingSourceKeepsCachedScore() async {
        let fixture = TodayFixture()
        let model = fixture.makeModel()
        await model.refresh()
        let scored = model.score
        #expect(model.lastSync == TodayClock.date("2026-11-02T08:00"))

        await fixture.source.setFails(true)
        fixture.clock.set("2026-11-02T09:00")
        await model.refresh()
        guard case .scored(let recovery) = model.score, case .scored(let first)? = scored else {
            Issue.record("Le score en cache était attendu, obtenu \(String(describing: model.score))")
            return
        }
        #expect(recovery.category == .optimal)
        #expect(recovery.score == first.score)
        #expect(model.lastSync == TodayClock.date("2026-11-02T08:00"))
    }

    @Test func dateTextIsFrench() async {
        let model = TodayFixture().makeModel()
        await model.refresh()
        #expect(model.dateText == "lundi 2 novembre")
    }
}
