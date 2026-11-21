import Foundation
import PulseDomain
import PulseServices
import Testing

struct StatsServiceTests {
    @Test func snapshotOnFixture() async throws {
        let repositories = try await StatsFixtures.twentyWeeks()
        let snapshot = try await repositories.service().snapshot(for: .month)

        #expect(snapshot.period == .month)
        #expect(snapshot.load.today != nil)
        // La 12e semaine est manquée : la meilleure série court de la 13e à la semaine en cours, déjà réussie.
        #expect(snapshot.attendance.best?.weeks == 8)
        #expect(snapshot.attendance.streak.streak == 8)
        #expect(snapshot.records.strength.first?.exercise == .content(id: "back-squat-barbell"))
        #expect(snapshot.records.runs[0].seconds != nil)
        #expect(snapshot.biometry.hrv != nil)
        #expect(snapshot.muscles.strengthSessions > 0)
    }

    @Test func emptyHistoryGivesEmptyViews() async throws {
        let snapshot = try await StatsRepositories().service().snapshot(for: .month)

        #expect(snapshot.load.today == nil)
        #expect(snapshot.load.daysUntilRatio != nil)
        #expect(snapshot.muscles.top.isEmpty)
        #expect(snapshot.attendance.weeks.count == 16)
        #expect(snapshot.records.runs.allSatisfy { $0.seconds == nil })
        #expect(snapshot.biometry.categories.count == 4)
    }

    @Test func aYearOfSessionsIsFast() async throws {
        let repositories = StatsRepositories()
        // 52 semaines de 5 séances de 20 séries, du lundi au vendredi.
        let plan = [StatsFixtures.push, StatsFixtures.pull, StatsFixtures.legs, StatsFixtures.push, StatsFixtures.legs]
        for number in 1...52 {
            // La dernière semaine est celle du 16 novembre ; `number` fait progresser les charges.
            let week = StatsFixtures.weeks - 52 + number
            for (offset, lifts) in plan.enumerated() {
                let start = StatsFixtures.day(offset, ofWeek: week, hour: 7)
                try await repositories.workouts.save(StatsFixtures.strengthSession(lifts, title: "Séance", start: start, week: number))
            }
        }
        let service = repositories.service()

        let clock = ContinuousClock()
        let elapsed = try await clock.measure { _ = try await service.snapshot(for: .year) }

        // Garde-fou en debug ; la cible de la spec est 200 ms sur l'iPhone en release.
        #expect(elapsed < .seconds(1))
    }
}
