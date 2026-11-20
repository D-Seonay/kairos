import Foundation
import PulseDomain
import PulseServices
import Testing

struct SupplementScheduleTests {
    private typealias Fixture = SupplementFixtures
    private let friday = TestClock.date("2026-11-20T00:00")
    private let saturday = TestClock.date("2026-11-21T00:00")

    @Test func trainingWeekdaysComeFromTheWeekLayout() {
        #expect(SupplementSchedule.trainingWeekdays(of: Fixture.program()) == [.monday, .tuesday, .wednesday, .thursday, .friday])
        #expect(SupplementSchedule.trainingWeekdays(of: nil).isEmpty)
    }

    @Test func daysDecideWhetherASupplementIsDue() {
        let everyDay = Fixture.supplement()
        let training = Fixture.supplement("Whey", timing: .afterWorkout, minutes: nil, days: .trainingDays)
        let custom = Fixture.supplement("Fer", days: .custom, weekdays: [.saturday])
        let archived = { var supplement = Fixture.supplement("Zinc"); supplement.isArchived = true; return supplement }()
        let later = Fixture.supplement("Oméga-3", created: TestClock.date("2026-11-21T09:00"))
        let schedule = Fixture.schedule([everyDay, training, custom, archived, later])

        #expect(schedule.items(on: friday).map(\.supplement.name) == ["Créatine", "Whey"])
        #expect(Set(schedule.items(on: saturday).map(\.supplement.name)) == ["Créatine", "Fer", "Oméga-3"])
    }

    @Test func aSessionMakesAnyDayATrainingDay() {
        let whey = Fixture.supplement("Whey", timing: .afterWorkout, minutes: nil, days: .trainingDays)
        let schedule = Fixture.schedule([whey], sessions: [Fixture.session(start: "2026-11-21T10:00", end: "2026-11-21T11:00")])
        #expect(schedule.items(on: saturday).map(\.supplement.name) == ["Whey"])
        #expect(schedule.items(on: TestClock.date("2026-11-22T00:00")).isEmpty)
    }

    @Test func habitualSessionTimeIsTheMedianOfRecentStartsToTheQuarterHour() {
        let sessions = [
            Fixture.session(start: "2026-11-16T17:50"), Fixture.session(start: "2026-11-17T18:10"),
            Fixture.session(start: "2026-11-18T18:20"),
            Fixture.session(start: "2026-11-19T07:00", status: .abandoned), Fixture.session(start: "2026-11-19T12:00", kind: .run)
        ]
        let schedule = Fixture.schedule([], sessions: sessions)
        #expect(schedule.habitualSessionMinutes(before: friday) == 18 * 60 + 15)
        #expect(Fixture.schedule([]).habitualSessionMinutes(before: friday) == 18 * 60)
    }

    @Test func workoutTimingFollowsTheSessionOfTheDay() throws {
        let caffeine = Fixture.supplement("Caféine", timing: .beforeWorkout, minutes: nil, days: .trainingDays, order: 0)
        let whey = Fixture.supplement("Whey", timing: .afterWorkout, minutes: nil, days: .trainingDays, order: 1)
        let planned = Fixture.schedule([caffeine, whey]).items(on: friday)
        #expect(planned.map(\.plannedMinutes) == [17 * 60 + 30, 19 * 60])
        #expect(planned.allSatisfy { $0.moment == .workout } && !planned[1].isWorkoutFinished)

        let done = Fixture.schedule([caffeine, whey], sessions: [Fixture.session(start: "2026-11-20T07:05", end: "2026-11-20T08:10")])
            .items(on: friday)
        #expect(done.map(\.plannedMinutes) == [6 * 60 + 35, 8 * 60 + 10])
        #expect(done[1].isWorkoutFinished)
    }

    @Test func momentsGroupFixedTimesByHour() {
        let morning = Fixture.supplement("A", minutes: 7 * 60)
        let afternoon = Fixture.supplement("B", minutes: 13 * 60)
        let evening = Fixture.supplement("C", minutes: 20 * 60)
        let bedtime = Fixture.supplement("D", timing: .bedtime, minutes: 22 * 60 + 30)
        let items = Fixture.schedule([bedtime, evening, afternoon, morning]).items(on: friday)
        #expect(items.map(\.moment) == [.morning, .afternoon, .evening, .evening])
        #expect(items.map(\.supplement.name) == ["A", "B", "C", "D"])
    }

    @Test func theLatestIntakeOfTheDayMarksItTaken() {
        let creatine = Fixture.supplement()
        let schedule = Fixture.schedule([creatine], intakes: [Fixture.intake(of: creatine, at: "2026-11-19T08:00"),
                                                        Fixture.intake(of: creatine, at: "2026-11-20T08:05")])
        let item = schedule.items(on: friday)[0]
        #expect(item.isTaken && item.intake?.takenAt == TestClock.date("2026-11-20T08:05"))
        #expect(!schedule.items(on: saturday)[0].isTaken)
    }
}

struct SupplementRegularityTests {
    private typealias Fixture = SupplementFixtures
    private let today = TestClock.date("2026-11-20T12:00")

    @Test func countsTakenDaysOverDueDaysSinceCreation() {
        let creatine = Fixture.supplement(created: TestClock.date("2026-11-11T08:00"))
        let intakes = ["2026-11-11", "2026-11-12", "2026-11-14", "2026-11-19"].map { Fixture.intake(of: creatine, at: "\($0)T08:00") }
        let regularity = SupplementRegularity.compute(for: creatine, schedule: Fixture.schedule([creatine], intakes: intakes), today: today)
        // Du 11 au 19 : 9 jours dus ; aujourd'hui, pas encore pris, ne compte pas.
        #expect(regularity == SupplementRegularity(takenDays: 4, dueDays: 9))
    }

    @Test func todayCountsOnceTaken() {
        let creatine = Fixture.supplement(created: TestClock.date("2026-11-19T08:00"))
        let intakes = [Fixture.intake(of: creatine, at: "2026-11-20T08:00")]
        let regularity = SupplementRegularity.compute(for: creatine, schedule: Fixture.schedule([creatine], intakes: intakes), today: today)
        #expect(regularity == SupplementRegularity(takenDays: 1, dueDays: 2))
        #expect(regularity.rate == 0.5)
    }

    @Test func trainingDaySupplementsOnlyCountTrainingDays() {
        let whey = Fixture.supplement("Whey", timing: .afterWorkout, minutes: nil, days: .trainingDays,
                                created: TestClock.date("2026-11-14T08:00"))
        let regularity = SupplementRegularity.compute(for: whey, schedule: Fixture.schedule([whey]), today: today)
        // Du samedi 14 au jeudi 19 : lundi à jeudi.
        #expect(regularity == SupplementRegularity(takenDays: 0, dueDays: 4))
        let fresh = Fixture.supplement(created: TestClock.date("2026-11-20T08:00"))
        #expect(SupplementRegularity.compute(for: fresh, schedule: Fixture.schedule([fresh]), today: today).rate == nil)
    }
}

struct SupplementHealthDoseTests {
    @Test func convertsToTheUnitOfEachType() {
        #expect(SupplementHealthDose.amount(dose: 1_000, unit: .iu, type: .vitaminD) == 25)
        #expect(SupplementHealthDose.amount(dose: 25, unit: .microgram, type: .vitaminD) == 25)
        #expect(SupplementHealthDose.amount(dose: 0.3, unit: .gram, type: .magnesium) == 300)
        #expect(SupplementHealthDose.amount(dose: 200, unit: .mg, type: .caffeine) == 200)
        #expect(SupplementHealthDose.amount(dose: 30, unit: .gram, type: .protein) == 30)
    }

    @Test func refusesUnitsWithoutAKnownQuantity() {
        #expect(SupplementHealthDose.amount(dose: 1, unit: .serving, type: .protein) == nil)
        #expect(SupplementHealthDose.amount(dose: 10, unit: .ml, type: .vitaminD) == nil)
        #expect(SupplementHealthDose.amount(dose: 400, unit: .iu, type: .magnesium) == nil)
        #expect(SupplementHealthDose.amount(dose: 0, unit: .mg, type: .caffeine) == nil)
        #expect(SupplementHealthDose.entryAmount(for: SupplementFixtures.supplement()) == nil)
    }
}

struct SupplementCatalogTests {
    private typealias Fixture = SupplementFixtures
    private let friday = TestClock.date("2026-11-20T00:00")

    @Test func suggestionsNeverCarryADose() {
        #expect(SupplementCatalog.suggestions.count == 9)
        #expect(Set(SupplementCatalog.suggestions.map(\.id)).count == 9)
    }

    @Test func caffeineAdviceOnlyFromFourPM() {
        let late = Fixture.supplement("Caféine", timing: .beforeWorkout, minutes: nil, days: .everyDay, health: .caffeine)
        let items = Fixture.schedule([late]).items(on: friday)
        #expect(SupplementCatalog.advice(for: items).map(\.kind) == [.caffeineLate])

        let morning = Fixture.supplement("Café vert", minutes: 9 * 60)
        #expect(SupplementCatalog.advice(for: Fixture.schedule([morning]).items(on: friday)).isEmpty)
    }

    @Test func oneAdvicePerKindInSupplementOrder() {
        let vitamin = Fixture.supplement("Vitamine D3", order: 0)
        let creatine = Fixture.supplement("Créatine monohydrate", order: 1)
        let iron = Fixture.supplement("Fer bisglycinate", order: 2)
        let other = Fixture.supplement("Vitamine D + K2", order: 3)
        let advice = SupplementCatalog.advice(for: Fixture.schedule([vitamin, creatine, iron, other]).items(on: friday))
        #expect(advice.map(\.kind) == [.vitaminDWithMeal, .creatineRegularity, .ironAndCoffee])
    }
}

extension SupplementScheduleTests {
    @Test func aRunFromAppleHealthIsNotATrainingSession() {
        let whey = SupplementFixtures.supplement("Whey", timing: .afterWorkout, minutes: nil, days: .trainingDays)
        let run = SupplementFixtures.session(start: "2026-11-21T07:30", end: "2026-11-21T08:15", kind: .run)
        let schedule = SupplementFixtures.schedule([whey], sessions: [run])
        #expect(schedule.isDue(whey, on: TestClock.date("2026-11-21T12:00")) == false, "Samedi n'est pas un jour d'entraînement")
    }
}
