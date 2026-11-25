import Foundation
import PlanningFeature
import PulseDomain
import PulseServices
import Testing

@MainActor
struct MonthModelTests {
    private func day(_ model: MonthModel, _ number: Int) throws -> MonthDay {
        let date = PlanningClock.date(day: number)
        return try #require(model.grid?.weeks.joined().first { $0.date == date })
    }

    @Test func aTouchedDayOpensWhatItHolds() async throws {
        let fixture = PlanningFixture()
        try await fixture.activate()
        _ = try await fixture.log(day: 10, hour: 7, kind: .run, meters: 5_000, source: .appleHealth)
        let strength = try await fixture.log(day: 10)
        let ride = try await fixture.log(day: 12, kind: .ride, source: .appleHealth)
        let model = MonthModel(environment: fixture.environment, streak: nil, historyStart: nil)
        await model.load()

        #expect(model.action(for: try day(model, 10)) == .open(.session(strength.id)), "La musculation passe avant la course")
        #expect(model.action(for: try day(model, 12)) == .open(.activity(ride.id)))
        #expect(model.action(for: try day(model, 11)) == nil, "Un jour passé sans séance n'ouvre rien")
        #expect(model.action(for: try day(model, 19)) == .showInWeek(PlanningClock.date(day: 19)), "Course prévue cette semaine")
        #expect(model.action(for: try day(model, 21)) == nil, "Samedi est un jour de repos")
        #expect(model.action(for: try day(model, 23)) == nil, "Au-delà de la semaine, rien ne montre le jour prévu")
    }

    @Test func eachActionHasItsSpokenHint() async throws {
        let model = MonthModel(environment: PlanningFixture().environment, streak: nil, historyStart: nil)
        #expect(model.accessibilityHint(of: .open(.session(UUID()))) == "Ouvre la séance")
        #expect(model.accessibilityHint(of: .open(.activity(UUID()))) == "Ouvre l'activité")
        #expect(model.accessibilityHint(of: .showInWeek(.now)) == "Montre ce jour dans la semaine")
    }
}
