import Foundation
import PulseDomain
import PulseServices
import Testing

struct SupplementReminderPlannerTests {
    private typealias Fixture = SupplementFixtures
    private let now = TestClock.date("2026-11-20T09:00")

    @Test func plansOneReminderPerDueDayFromNowOn() {
        let vitamin = Fixture.supplement("Vitamine D3", minutes: 8 * 60)
        let magnesium = Fixture.supplement("Magnésium", timing: .bedtime, minutes: 22 * 60 + 30, order: 1)
        let reminders = SupplementReminderPlanner.reminders(schedule: Fixture.schedule([vitamin, magnesium]), now: now, enabled: true)
        // Ce matin 8:00 est passé : la vitamine D commence demain ; le magnésium ce soir.
        #expect(reminders.first?.fireDate == TestClock.date("2026-11-20T22:30"))
        #expect(reminders.first?.title == "Magnésium")
        #expect(reminders.filter { $0.supplementID == vitamin.id }.count == 13)
        #expect(reminders.filter { $0.supplementID == magnesium.id }.count == 14)
        #expect(reminders[1].fireDate == TestClock.date("2026-11-21T08:00"))
        #expect(reminders[1].day == TestClock.date("2026-11-21T00:00"))
    }

    @Test func skipsTakenDaysRemindersOffAndTheGlobalSwitch() {
        let creatine = Fixture.supplement(minutes: 20 * 60)
        let silent = Fixture.supplement("Zinc", reminder: false)
        let schedule = Fixture.schedule([creatine, silent], intakes: [Fixture.intake(of: creatine, at: "2026-11-20T07:00")])
        let reminders = SupplementReminderPlanner.reminders(schedule: schedule, now: now, enabled: true)
        #expect(reminders.allSatisfy { $0.supplementID == creatine.id })
        #expect(reminders.first?.fireDate == TestClock.date("2026-11-21T20:00"))
        #expect(SupplementReminderPlanner.reminders(schedule: schedule, now: now, enabled: false).isEmpty)
    }

    @Test func beforeWorkoutOnTrainingDaysOnly() {
        let caffeine = Fixture.supplement("Caféine", timing: .beforeWorkout, minutes: nil, days: .everyDay)
        let reminders = SupplementReminderPlanner.reminders(schedule: Fixture.schedule([caffeine]), now: now, enabled: true)
        // Vendredi, puis lundi à vendredi suivants, puis lundi et mardi : 10 jours d'entraînement sur 14.
        #expect(reminders.count == 10)
        #expect(reminders.first?.fireDate == TestClock.date("2026-11-20T17:30"))
        #expect(!reminders.contains { TestClock.calendar.isDate($0.day, inSameDayAs: TestClock.date("2026-11-21T00:00")) })
    }

    @Test func afterWorkoutWaitsForTheEndOfTheSession() {
        let whey = Fixture.supplement("Whey", timing: .afterWorkout, minutes: nil, days: .trainingDays)
        let before = SupplementReminderPlanner.reminders(schedule: Fixture.schedule([whey]), now: now, enabled: true)
        #expect(before.isEmpty)

        let finished = Fixture.schedule([whey], sessions: [Fixture.session(start: "2026-11-20T07:30", end: "2026-11-20T08:40")])
        let after = SupplementReminderPlanner.reminders(schedule: finished, now: now, enabled: true)
        #expect(after.map(\.fireDate) == [TestClock.date("2026-11-20T09:25")])
    }

    @Test func keepsTheEarliestFortyEight() {
        let many = (0..<5).map { Fixture.supplement("S\($0)", minutes: 10 * 60 + $0, order: $0) }
        let reminders = SupplementReminderPlanner.reminders(schedule: Fixture.schedule(many), now: now, enabled: true)
        #expect(reminders.count == SupplementReminderPlanner.maximumCount)
        #expect(reminders == reminders.sorted { $0.fireDate < $1.fireDate })
    }
}
