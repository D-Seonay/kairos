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
        // La 12e semaine est manquée : la meilleure série (semaines 1 à 11) précède la série en cours (13e à 20e semaine).
        #expect(snapshot.attendance.best?.weeks == 11)
        #expect(snapshot.attendance.best?.firstWeek == StatsFixtures.monday(ofWeek: 1))
        #expect(snapshot.attendance.best?.lastWeek == StatsFixtures.monday(ofWeek: 11))
        #expect(snapshot.attendance.streak.streak == 8)
        #expect(snapshot.records.strength.first?.exercise == .content(id: "back-squat-barbell"))
        #expect(snapshot.records.runs[0].seconds != nil)
        #expect(snapshot.biometry.hrv != nil)
        #expect(snapshot.muscles.strengthSessions > 0)
    }

    @Test func runRecordsReadTheBestSegmentCache() async throws {
        let repositories = StatsRepositories()
        let start = StatsFixtures.now.addingTimeInterval(-3 * 86_400)
        let run = WorkoutSession(startedAt: start, kind: .run, source: .pulse, status: .completed, title: "Course",
                                 durationMinutes: 66, distanceMeters: 12_000, createdAt: start, updatedAt: start)
        try await repositories.workouts.save(run)
        await repositories.runEfforts.save([RunBestEfforts(id: run.id, efforts: [RunBestEffort(meters: 5_000, seconds: 1_350)])])

        let snapshot = try await repositories.service().snapshot(for: .month)
        #expect(snapshot.records.runs[0].seconds == 1_350 && snapshot.records.runs[0].isSegment)
        let summary = try await repositories.profileService().summary()
        #expect(summary.runs[0].seconds == 1_350)
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
