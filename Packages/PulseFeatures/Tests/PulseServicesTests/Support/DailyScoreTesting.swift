import Foundation
import PulseContent
import PulseDomain
import PulseServices
import Testing

/// Les tests du cycle de vie du score se passent de programme : aucune séance à ajuster.
extension DailyScoreService {
    func update(nights: [NightSample], now: Date) async throws -> TodayScore {
        try await update(nights: nights, plannedDay: .noProgram, now: now)
    }

    func saveCheckIn(_ answers: CheckInAnswers, now: Date) async throws -> DailyRecovery {
        try await saveCheckIn(answers, plannedDay: .noProgram, now: now)
    }
}

/// Un service du score au-dessus d'un dépôt en mémoire que le test peut relire.
struct DailyScoreFixture {
    let repository: InMemoryRecoveryRepository
    let service: DailyScoreService
}

enum DailyScoreTestFailure: Error { case notScored(TodayScore) }

/// Les aides partagées par les suites du score du jour.
protocol DailyScoreTesting {}

extension DailyScoreTesting {
    var calendar: Calendar { TestClock.calendar }

    func fixture() -> DailyScoreFixture {
        let repository = InMemoryRecoveryRepository(calendar: calendar)
        return DailyScoreFixture(repository: repository, service: DailyScoreService(recovery: repository, calendar: calendar))
    }

    func nights(_ scenario: HealthScenario, at now: Date) async -> [NightSample] {
        let source = ScenarioHealthSource(scenario: scenario, now: now, calendar: calendar)
        let history = NightHistory(source: source, cache: InMemoryHealthSampleCache(), calendar: calendar)
        return await history.refresh(now: now).nights
    }

    func records(_ fixture: DailyScoreFixture, on text: String) async throws -> [DailyRecovery] {
        let day = TestClock.date(text)
        return try await fixture.repository.dailyRecoveries(from: day, to: calendar.date(byAdding: .day, value: 1, to: day) ?? day)
    }

    func scored(_ score: TodayScore) throws -> DailyRecovery {
        guard case .scored(let recovery) = score else {
            throw DailyScoreTestFailure.notScored(score)
        }
        return recovery
    }

    /// Le jour prévu par PPL 3 adopté (salle complète) : lundi Push, mardi repos.
    func plannedDay(at now: Date) throws -> PlannedDay {
        let template = try #require(ContentLibrary.bundled.programTemplate(id: "ppl-3"))
        let program = ProgramAdopter(library: .bundled).adopt(template, equipment: .fullGym, painAreas: [], restWeekdays: [], now: now)
        return TodayPlanner.plan(program: program, on: now, calendar: calendar)
    }
}
